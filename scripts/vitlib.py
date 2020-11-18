import binascii
import cbor2
import json
import subprocess
import tempfile
import os
import psycopg2

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

    @staticmethod
    def write_key(name, contents):
        with open(name, "w") as f:
            f.write(contents)
            f.close()

    @staticmethod
    def read_cardano_key(name):
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

    @staticmethod
    def read_jcli_key(key_path):
        with open(key_path) as f:
            return f.read().rstrip()

    @staticmethod
    def convert_jcli_key_to_bytes(key):
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

    @staticmethod
    def convert_key_to_jcli(key):
        cli_args = [ "jcli", "key", "from-bytes", "--type", "ed25519" ]
        p = subprocess.run(cli_args, capture_output=True, text=True, input=key, encoding='ascii')

        if p.returncode != 0:
            print(p.stderr)
            raise Exception("Unknown error converting from hex to bech32")
        return p.stdout.rstrip()

    @staticmethod
    def jcli_key_public(skey):
        cli_args = [ "jcli", "key", "to-public" ]
        p = subprocess.run(cli_args, capture_output=True, text=True, input=skey, encoding='ascii')
        if p.returncode != 0:
            print(p.stderr)
            raise Exception("Unknown error converting to public")
        return p.stdout.rstrip()

    @staticmethod
    def bech32_to_hex(bech32_string):
        cli_args = [ "bech32" ]
        p = subprocess.run(cli_args, capture_output=True, text=True, input=bech32_string, encoding='ascii')
        if p.returncode != 0:
            print(p.stderr)
            raise Exception("Unknown error converting bech32 string to hex")
        return p.stdout.rstrip()

    @staticmethod
    def prefix_bech32(prefix, key):
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

    @staticmethod
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

    @staticmethod
    def jcli_generate_share(encrypted_tally_path, decryption_key_path):
        cli_args = [
            "jcli", "votes", "tally", "decryption-share",
            "--encrypted-tally", encrypted_tally_path,
            "--decryption-key", decryption_key_path
        ]
        try:
            result = subprocess.check_output(cli_args)
            return json.loads(result)
        except subprocess.CalledProcessError as e:
            print(f"Error executing process, exit code {e.returncode}:\n{e.output}")

    @staticmethod
    def jcli_decrypt_tally(encrypted_tally_path, shares_path, threshold, max_votes, table_size, output_format="json"):
        cli_args = [
            "jcli", "votes", "tally", "decrypt",
            "--encrypted-tally", encrypted_tally_path,
            "--shares", shares_path,
            "--threshold", threshold,
            "--max-votes", max_votes,
            "--table-size", table_size,
            "--output-format", output_format
        ]
        try:
            result = subprocess.check_output(cli_args)
            if output_format.lower() == "json":
                return json.loads(result)
            return result
        except subprocess.CalledProcessError as e:
            print(f"Error executing process, exit code {e.returncode}:\n{e.output}")

    @staticmethod
    def generate_committee_member_shares(rest_api_url, decryption_key_path, output_file="./proposals.shares"):
        # some imports needed just for this method
        import requests

        full_url = f"{rest_api_url}/v0/vote/active/plans"
        try:
            active_vote_plans = requests.get(full_url).json()
        except ValueError:
            raise Exception(f"Couldn't get a proper json reply from {rest_api_url}")

        # Active voteplans dict would look like:
        # {
        #   id: Hash,
        #   payload: PauloadType,
        #   vote_start: BlockDate,
        #   vote_end: BlcokDate,
        #   committee_end: BlockDate,
        #   committee_member_keys: [MemberPublicKey]
        #   proposals: [
        #       index: int,
        #       proposal_id: Hash,
        #       options: [u8],
        #       tally: Tally(Public or Private),
        #       votes_cast: int,
        #   ]
        # }
        proposals = active_vote_plans["proposals"]
        for proposal in proposals:
            try:
                encrypted_tally = proposal["tally"]["private"]["encrypted"]["encrypted_tally"]
            except KeyError:
                raise Exception(f"Tally data wasn't expected:\n{proposal}")
            f, tmp_tally_path = tempfile.mkstemp()
            with open(tmp_tally_path, "w") as f:
                f.write(encrypted_tally)
            # result is of format:
            # {
            #   state: base64,
            #   share: base64
            # }
            result = VITBridge.jcli_generate_share(tmp_tally_path, decryption_key_path)
            proposal["shares"] = result["share"]

        with open(output_file, "w") as f:
            json.dump(f, proposals, indent=4)
        print(f"Shares file processed properly at: {output_file}")

    @staticmethod
    def merge_generated_shares(*share_files_paths, output_file="aggregated_shares.shares"):
        from functools import reduce

        def load_data(path):
            with open(path) as f:
                return json.load(f)

        def merge_two_shares_data(data1, data2):
            data1["shares"].append(data2.pop())
            return data1

        shares_data = (load_data(p) for p in share_files_paths)
        full_data = reduce(merge_two_shares_data, shares_data)
        with open(output_file, "w") as f:
            json.dump(f, full_data)
        print(f"Data succesfully aggregated at: {output_file}")

    @staticmethod
    def tally_with_shares(aggregated_data_shares_file, output_file="decrypted_tally"):

        def write_shares(f, shares):
            for s in shares:
                f.writeline(s)

        def write_tally(f, tally):
            f.write(tally)

        with open(aggregated_data_shares_file) as f:
            try:
                aggregated_data = json.load(f)
            except ValueError:
                raise Exception(f"Error loading data from file: {aggregated_data_shares_file}")

        for data in aggregated_data:
            try:
                encrypted_tally = data["tally"]["private"]["encrypted"]["encrypted_tally"]
                shares = data["shares"]
            except KeyError:
                raise Exception(f"Tally data wasn't expected:\n{data}")

            _, tmp_tally_file = tempfile.mkstemp()
            _, tmp_shares_file = tempfile.mkstemp()

            with open(tmp_tally_file, "w") as tally_f, open(tmp_shares_file, "w") as shares_f:
                write_tally(tally_f, encrypted_tally)
                write_shares(shares_f, shares)

            threshold = len(shares)
            max_votes = data["votes_cast"]
            options = data["options"]["end"]
            table_size = max_votes // options

            result = VITBridge.jcli_decrypt_tally(
                tmp_tally_file, tmp_shares_file, threshold, max_votes, table_size
                )

            data["tally"]["tally_result"] = result

        with open(output_file, "w") as f:
            json.dump(f, aggregated_data)

        print("Tally successfully decrypted")








