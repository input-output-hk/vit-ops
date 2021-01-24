import binascii
import cbor2
import json
import subprocess
import tempfile
import time
import os
import psycopg2
import sys


class VITBridge:
    """VIT tools to bridge Cardano mainnet and jormungandr"""

    def __init__(self, network_magic, state_dir, db=None, dbuser="", dbhost=""):
        self.network_magic = int(network_magic)
        if self.network_magic == 0:
            self.magic_args = ["--mainnet"]
        else:
            self.magic_args = ["--testnet-magic", str(network_magic)]
        self.state_dir = state_dir
        if db:
            self.db = psycopg2.connect(user=dbuser, host=dbhost, database=db)

    def write_text(self, name, contents):
        with open(name, "w") as f:
            f.write(contents)
            f.close()

    def write_bytes(self, name, contents):
        with open(name, "wb") as f:
            f.write(contents)
            f.close()

    def read_cardano_key(self, name):
        with open(name) as f:
            data = json.load(f)["cborHex"]
            return binascii.hexlify(cbor2.loads(binascii.unhexlify(data))).decode(
                "ascii"
            )

    def get_cardano_vkey(self, skey_file):
        (tf1, vkey_file) = tempfile.mkstemp()
        cli_args = [
            "cardano-cli",
            "shelley",
            "key",
            "verification-key",
            "--signing-key-file",
            skey_file,
            "--verification-key-file",
            vkey_file,
        ]
        p = subprocess.run(cli_args, capture_output=True, text=True)
        if p.returncode != 0:
            print(p.stderr)
            raise Exception("Unknown error deriving cardano vkey from skey")
        vkey = self.read_cardano_key(vkey_file)
        os.close(tf1)
        os.unlink(vkey_file)
        return vkey

    def read_jcli_key(self, name):
        with open(name) as f:
            return f.read().rstrip()

    def convert_jcli_key_to_bytes(self, key):
        cli_args = ["jcli", "key", "to-bytes"]
        p = subprocess.run(
            cli_args, capture_output=True, text=True, input=key, encoding="ascii"
        )
        if p.returncode != 0:
            raise Exception("Unknown error converting jcli key to bytes")
        return p.stdout.rstrip()

    def jcli_sign(self, key, contents, text=False):
        (tf1, key_file) = tempfile.mkstemp()
        (tf2, contents_file) = tempfile.mkstemp(suffix=b"", text=text)
        self.write_text(key_file, key)
        if text:
            self.write_text(contents_file, contents)
        else:
            self.write_bytes(contents_file, contents)
        cli_args = ["jcli", "key", "sign", "--secret-key", key_file, contents_file]
        p = subprocess.run(cli_args, capture_output=True, text=True)
        os.close(tf1)
        os.close(tf2)
        os.unlink(key_file)
        os.unlink(contents_file)
        if p.returncode != 0:
            raise Exception("Unknown error signing")
        return p.stdout.rstrip()

    def convert_key_to_jcli(self, key):
        cli_args = ["jcli", "key", "from-bytes", "--type", "ed25519"]
        p = subprocess.run(
            cli_args, capture_output=True, text=True, input=key, encoding="ascii"
        )
        if p.returncode != 0:
            print(p.stderr)
            raise Exception("Unknown error converting from hex to bech32")
        return p.stdout.rstrip()

    def jcli_key_public(self, skey):
        cli_args = ["jcli", "key", "to-public"]
        p = subprocess.run(
            cli_args, capture_output=True, text=True, input=skey, encoding="ascii"
        )
        if p.returncode != 0:
            print(p.stderr)
            raise Exception("Unknown error converting to public")
        return p.stdout.rstrip()

    def jcli_address(self, pubkey, prefix="ca"):
        pubkey = self.prefix_bech32("ed25519_pk", pubkey)
        cli_args = ["jcli", "address", "single", pubkey, "--prefix", prefix]
        p = subprocess.run(cli_args, capture_output=True, text=True)
        if p.returncode != 0:
            print(p.stderr)
            raise Exception("Unknown error generating address from public key")
        return p.stdout.rstrip()

    def bech32_to_hex(self, bech32_string):
        cli_args = ["bech32"]
        p = subprocess.run(
            cli_args,
            capture_output=True,
            text=True,
            input=bech32_string,
            encoding="ascii",
        )
        if p.returncode != 0:
            print(p.stderr)
            raise Exception("Unknown error converting bech32 string to hex")
        return p.stdout.rstrip()

    def prefix_bech32(self, prefix, key):
        cli_args = ["bech32", prefix]
        p = subprocess.run(
            cli_args, capture_output=True, text=True, input=key, encoding="ascii"
        )
        if p.returncode != 0:
            print(p.stderr)
            raise Exception("Unknown error converting bech32 string to hex")
        return p.stdout.rstrip()

    def validate_sig(self, pub_key, sig, data, text=False):
        (tf1, pub_key_file) = tempfile.mkstemp()
        (tf2, data_file) = tempfile.mkstemp(suffix=b"", text=text)
        (tf3, sig_file) = tempfile.mkstemp()
        self.write_text(pub_key_file, pub_key)
        self.write_text(sig_file, sig)
        if text:
            self.write_text(data_file, data)
        else:
            self.write_bytes(data_file, data)
        cli_args = [
            "jcli",
            "key",
            "verify",
            "--public-key",
            pub_key_file,
            "--signature",
            sig_file,
            data_file,
        ]
        p = subprocess.run(cli_args, capture_output=True, text=True)
        os.close(tf1)
        os.close(tf2)
        os.close(tf3)
        os.unlink(pub_key_file)
        os.unlink(data_file)
        os.unlink(sig_file)
        if p.returncode != 0:
            return False
        else:
            return True

    def meta_convert_raw(self, meta):
        if 1 in meta and 2 in meta:
            return {
                61284: {1: bytes.fromhex(meta[1][2:]), 2: bytes.fromhex(meta[2][2:]),}
            }
        return meta

    def generate_meta_data(self, stake, vote):
        stake_priv = self.prefix_bech32("ed25519_sk", stake)
        stake_pub = self.jcli_key_public(stake_priv)
        stake_pub_hex = self.convert_jcli_key_to_bytes(stake_pub)
        meta_keys = {
            1: f"0x{vote}",
            2: f"0x{stake_pub_hex}",
        }
        meta_keys_raw = self.meta_convert_raw(meta_keys)
        sig = self.bech32_to_hex(self.jcli_sign(stake_priv, cbor2.dumps(meta_keys_raw)))
        meta = {61284: meta_keys, 61285: {1: f"0x{sig}"}}
        return meta

    def validate_meta_data_presubmit(self, meta):
        if 61284 in meta and 61285 in meta and 1 in meta[61285]:
            return self.validate_meta_data(meta[61284], meta[61285][1])

    def validate_meta_data(self, meta, signature):
        meta_raw = self.meta_convert_raw(meta)
        stake_pub = self.prefix_bech32("ed25519_pk", self.strip_hex_prefix(meta[2]))
        sig = self.prefix_bech32("ed25519_sig", self.strip_hex_prefix(signature))
        return self.validate_sig(stake_pub, sig, cbor2.dumps(meta_raw))

    def get_stake_hash(self, stake_vkey):
        cli_args = [
            "cardano-cli",
            "shelley",
            "stake-address",
            "build",
            *self.magic_args,
            "--stake-verification-key",
            stake_vkey,
        ]
        p = subprocess.run(cli_args, capture_output=True, text=True)
        if p.returncode != 0:
            print(p.stderr)
            raise Exception("Unknown error generating stake address")
        return p.stdout.rstrip()

    def strip_hex_prefix(self, contents):
        if contents and contents[0:2] == "0x":
            return contents[2:]
        else:
            return None

    def fetch_voting_keys(self, slot=None):
        cursor = self.db.cursor()
        # TODO: maybe add psycopg2.extra for parsing the json
        # cursor.execute('''SELECT json ->> 'purpose' AS purpose, json ->> 'stake_pub' AS stake_pub, json ->> 'voting_key' AS voting_key, json ->> 'signature' AS signature FROM tx INNER JOIN tx_metadata ON tx.id = tx_metadata.tx_id WHERE json ->> 'purpose' = 'voting_registration';''')
        # cursor.execute('''SELECT txid, txhash, json[1] AS meta, json[2] AS sig FROM ( SELECT tx.hash AS txhash, tx_metadata.tx_id AS txid, array_agg(json) json FROM tx_metadata INNER JOIN tx ON tx_metadata.tx_id = tx.id WHERE key IN (61284, 61285) GROUP BY tx.hash, tx_metadata.tx_id ORDER BY tx_metadata.tx_id ) z;''')
        if slot:
            cursor.execute(
                f"""WITH meta_table AS (select tx_id, json AS metadata from tx_metadata where key = '61284')
   , sig_table AS (select tx_id, json AS signature from tx_metadata where key = '61285')
SELECT tx.hash,tx_id,metadata,signature FROM meta_table INNER JOIN tx ON tx.id = meta_table.tx_id INNER JOIN block ON block.id = tx.block_id INNER JOIN sig_table USING(tx_id) WHERE block.slot_no < {slot};"""
            )
        else:
            cursor.execute(
                """WITH meta_table AS (select tx_id, json AS metadata from tx_metadata where key = '61284')
   , sig_table AS (select tx_id, json AS signature from tx_metadata where key = '61285')
SELECT tx.hash,tx_id,metadata,signature FROM meta_table INNER JOIN tx ON tx.id = meta_table.tx_id INNER JOIN sig_table USING(tx_id);"""
            )
        rows = cursor.fetchall()
        keys = {}
        timer = time.time()
        print(f"    Raw DB query rows returned: {len(rows)}", file=sys.stderr)
        for i, row in enumerate(rows, start=1):
            if (
                (type(row[2]) is dict)
                and (type(row[3]) is dict)
                and ("1" in row[2])
                and ("2" in row[2])
                and "1" in row[3]
            ):
                meta = {1: row[2]["1"], 2: row[2]["2"]}
                stake_pub = self.strip_hex_prefix(meta[2])
                voting_key = self.strip_hex_prefix(meta[1])
                signature = row[3]["1"]
                if (
                    stake_pub
                    and voting_key
                    and signature
                    and self.validate_meta_data(meta, signature)
                ):
                    stake_hash = self.bech32_to_hex(self.get_stake_hash(stake_pub))[2:]
                    keys[stake_hash] = voting_key
            print(f"\r    Processing key {i} of {len(rows)}", end="", file=sys.stderr)
        print(f" [{time_delta_to_str(time.time() - timer)}]", file=sys.stderr)
        return keys

    def debug_single_tx(self, txhash):
        cursor = self.db.cursor()
        cursor.execute(
            f"""WITH meta_table AS (select tx_id, json AS metadata from tx_metadata where key = '61284')
   , sig_table AS (select tx_id, json AS signature from tx_metadata where key = '61285')
SELECT hash,tx_id,metadata,signature FROM meta_table INNER JOIN tx ON tx.id = meta_table.tx_id INNER JOIN sig_table USING(tx_id) WHERE hash=decode('{txhash}', 'hex');"""
        )
        row = cursor.fetchone()
        if (
            (type(row[2]) is dict)
            and (type(row[3]) is dict)
            and ("1" in row[2])
            and ("2" in row[2])
            and "1" in row[3]
        ):
            meta = {1: row[2]["1"], 2: row[2]["2"]}
            stake_pub = self.strip_hex_prefix(meta[2])
            voting_key = self.strip_hex_prefix(meta[1])
            signature = row[3]["1"]
            sig_hex = self.strip_hex_prefix(signature)
            if (
                stake_pub
                and voting_key
                and signature
                and self.validate_meta_data(meta, signature)
            ):
                print(
                    f"""
valid signature!
stake_pub: {stake_pub}
voting_key: {voting_key}
signature: {sig_hex}
                """
                )
            else:
                meta_raw = cbor2.dumps(self.meta_convert_raw(meta))
                stake_pub_bech32 = self.prefix_bech32(
                    "ed25519_pk", self.strip_hex_prefix(meta[2])
                )
                sig_bech32 = self.prefix_bech32(sig_hex)
                pub_key_file = "debug.pub"
                data_file = "debug.data"
                sig_file = "debug.sig"
                self.write_text(pub_key_file, stake_pub_bech32)
                self.write_text(sig_file, sig_bech32)
                self.write_bytes(data_file, meta_raw)
                print(
                    f"""
tx failed to validate!
stake_pub: {stake_pub}
voting_key: {voting_key}
signature: {sig_hex}

debug files written in current directory
                """
                )

    def get_stake(self, stake_hash, slot=None):
        cursor = self.db.cursor()
        query_tx_id = f"""SELECT tx.id FROM tx LEFT OUTER JOIN block ON block.id = tx.block_id WHERE block.slot_no > {slot} LIMIT 1"""
        cursor.execute(query_tx_id)
        row = cursor.fetchone()
        if row[0]:
            txid = int(row[0])
        # TODO: pass stake_hash in tuple with %s
        if slot:
            query = f"""SELECT SUM(tx_out.value) FROM tx_out INNER JOIN tx ON tx.id = tx_out.tx_id LEFT OUTER JOIN tx_in ON tx_out.tx_id = tx_in.tx_out_id AND tx_out.index = tx_in.tx_out_index AND tx_in_id < {txid} INNER JOIN block ON block.id = tx.block_id AND block.slot_no < {slot} WHERE CAST(encode(address_raw, 'hex') AS text) LIKE '%{stake_hash}' AND tx_in.tx_in_id is null;"""
        else:
            query = f"""SELECT SUM(utxo_view.value) FROM utxo_view WHERE CAST(encode(address_raw, 'hex') AS text) LIKE '%{stake_hash}';"""
        cursor.execute(query)
        row = cursor.fetchone()
        if row[0]:
            return int(row[0].to_integral_value())
        return 0


def time_delta_to_str(time_delta, ms=True):
    """ Returns a user friendly hh:mm:ss[.SSS] string given a time().time delta """

    hours, rem = divmod(time_delta, 3600)
    minutes, seconds = divmod(rem, 60)

    if ms:
        time_string = f"{int(hours):02.0f}:{int(minutes):02.0f}:{seconds:06.3f}"
    else:
        time_string = f"{int(hours):02.0f}:{int(minutes):02.0f}:{int(seconds):02.0f}"

    return time_string
