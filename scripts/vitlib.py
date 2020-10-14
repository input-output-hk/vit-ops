import binascii
import cbor2
import json
import subprocess
import tempfile
import os
import psycopg2

from cardanolib import CardanoCLIWrapper

class VITBridge:
    """VIT tools to bridge Cardano mainnet and jormungandr"""

    def __init__(self, network_magic, state_dir, db=None, dbuser="", dbhost=""):
        self.network_magic = network_magic
        if network_magic == 0:
            self.magic_args = [ "--mainnet" ]
        else:
            self.magic_args = [ "--testnet-magic", str(network_magic) ]
        self.state_dir = state_dir
        if db:
            self.db = psycopg2.connect(user=dbuser, host=dbhost, database=db)

    def write_key(self, name, contents):
        with open(name, "w") as f:
            f.write(contents)
            f.close()

    def read_cardano_key(self, name):
        with open(name) as f:
            data = json.load(f)["cborHex"]
            return binascii.hexlify(cbor2.loads(binascii.unhexlify(data))).decode("ascii")

    def get_cardano_vkey(self, skey_file):
        (tf, vkey_file) = tempfile.mkstemp()
        cli_args = [ "cardano-cli", "shelley", "key", "verification-key", "--signing-key-file", skey_file, "--verification-key-file", vkey_file ]
        p = subprocess.run(cli_args, capture_output=True, text=True)
        if p.returncode != 0:
            print(p.stderr)
            raise Exception("Unknown error deriving cardano vkey from skey")
        vkey = self.read_cardano_key(vkey_file)
        os.unlink(vkey_file)
        return vkey

    def read_jcli_key(self, name):
        with open(name) as f:
            return f.read().rstrip()

    def convert_jcli_key_to_bytes(self, key):
        cli_args = [ "jcli", "key", "to-bytes" ]
        p = subprocess.run(cli_args, capture_output=True, text=True, input=key, encoding='ascii')
        if p.returncode != 0:
            raise Exception("Unknown error converting jcli key to bytes")
        return p.stdout.rstrip()

    def jcli_sign(self, key, text):
        (tf, key_file) = tempfile.mkstemp()
        (tf, text_file) = tempfile.mkstemp()
        self.write_key(key_file, key)
        self.write_key(text_file, text)
        cli_args = [ "jcli", "key", "sign", "--secret-key", key_file, text_file ]
        p = subprocess.run(cli_args, capture_output=True, text=True)
        os.unlink(key_file)
        os.unlink(text_file)
        if p.returncode != 0:
            raise Exception("Unknown error signing")
        return p.stdout.rstrip()

    def convert_key_to_jcli(self, key):
        cli_args = [ "jcli", "key", "from-bytes", "--type", "ed25519" ]
        p = subprocess.run(cli_args, capture_output=True, text=True, input=key, encoding='ascii')

        if p.returncode != 0:
            print(p.stderr)
            raise Exception("Unknown error converting from hex to bech32")
        return p.stdout.rstrip()

    def jcli_key_public(self, skey):
        cli_args = [ "jcli", "key", "to-public" ]
        p = subprocess.run(cli_args, capture_output=True, text=True, input=skey, encoding='ascii')
        if p.returncode != 0:
            print(p.stderr)
            raise Exception("Unknown error converting to public")
        return p.stdout.rstrip()


    def bech32_to_hex(self, bech32_string):
        cli_args = [ "bech32" ]
        p = subprocess.run(cli_args, capture_output=True, text=True, input=bech32_string, encoding='ascii')
        if p.returncode != 0:
            print(p.stderr)
            raise Exception("Unknown error converting bech32 string to hex")
        return p.stdout.rstrip()

    def prefix_bech32(self, prefix, key):
        cli_args = [ "bech32", prefix ]
        p = subprocess.run(cli_args, capture_output=True, text=True, input=key, encoding="ascii")

        if p.returncode != 0:
            print(p.stderr)
            raise Exception("Unknown error converting bech32 string to hex")
        return p.stdout.rstrip()

    def validate_sig(self, pub_key, sig, data):
        (tf, pub_key_file) = tempfile.mkstemp()
        (tf, data_file) = tempfile.mkstemp()
        (tf, sig_file) = tempfile.mkstemp()
        self.write_key(pub_key_file, pub_key)
        self.write_key(sig_file, sig)
        self.write_key(data_file, data)
        cli_args = [ "jcli", "key", "verify", "--public-key", pub_key_file, "--signature", sig_file, data_file ]
        p = subprocess.run(cli_args, capture_output=True, text=True)
        os.unlink(pub_key_file)
        os.unlink(data_file)
        os.unlink(sig_file)
        if p.returncode != 0:
            print(p.stderr)
            return False
        else:
            return True

    def generate_meta_data(self, stake, vote, sig):
        meta = { "1": {
                "purpose": "voting_registration",
                "voting_key": f"0x{vote}",
                "stake_pub": f"0x{stake}",
                "signature": f"0x{sig}"
               }}
        return meta

    def validate_meta_data_presubmit(self, meta):
        return self.validate_meta_data(meta["1"]["stake_pub"][2:], meta["1"]["voting_key"][2:], meta["1"]["signature"][2:])

    def validate_meta_data(self, stake_pub, voting_key, signature):
        stake_pub = self.prefix_bech32("ed25519_pk", stake_pub)
        sig = self.prefix_bech32("ed25519_sig", signature)
        return self.validate_sig(stake_pub, sig, voting_key)

    def get_stake_hash(self, stake_vkey):
        cli_args = [ "cardano-cli", "shelley", "stake-address", "build", *self.magic_args, "--stake-verification-key", stake_vkey ]
        p = subprocess.run(cli_args, capture_output=True, text=True)
        if p.returncode != 0:
            print(p.stderr)
            raise Exception("Unknown error generating stake address")
        return p.stdout.rstrip()


    def fetch_voting_keys(self):
        cursor = self.db.cursor()
        # TODO: maybe add psycopg2.extra for parsing the json
        cursor.execute('''SELECT json ->> 'purpose' AS purpose, json -> 'stake_pub' ->> 'hex' AS stake_pub, json -> 'voting_key' ->> 'hex' AS voting_key, json -> 'signature' ->> 'hex' AS signature FROM tx INNER JOIN tx_metadata ON tx.id = tx_metadata.tx_id WHERE json ->> 'purpose' = 'voting_registration';''')
        rows = cursor.fetchall()
        keys = {}
        for row in rows:
            stake_pub = row[1]
            voting_key = row[2]
            signature = row[3]
            if stake_pub and voting_key and signature and self.validate_meta_data(stake_pub, voting_key, signature):
                stake_hash = self.bech32_to_hex(self.get_stake_hash(stake_pub))[2:]
                keys[stake_hash] = voting_key
        return keys

    def get_stake(self, stake_hash):
        cursor = self.db.cursor()
        # TODO: pass stake_hash in tuple with %s
        query = f'''SELECT SUM(value) FROM utxo_view WHERE CAST(encode(address_raw, 'hex') AS text) LIKE '%{stake_hash}';'''
        cursor.execute(query)
        row = cursor.fetchone()
        if row[0]:
            return int(row[0].to_integral_value())
        return 0
