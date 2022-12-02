# Catalyst Voting Tools

# Vote Registration

To register to vote, a ed25519extended key needs generated with jcli and a stake secret key and payment secret key need to be provided.

Usage:

```
nix-shell
jcli key generate --type ed25519extended > vote.sk
jcli key to-public < vote.sk > vote.pk
python vote-registration.py --payment-signing-key payment.skey --payment-address addr_test1vrd26p8d9dlknc4fhevzudcfzuul5qm2znquytugqcw583czzqrpm --vote-public-key vote.pk --stake-signing-key stake.skey
```

# Voter Key and Stake Export

To export voter the voter key and associated stake, cardano-db-sync is required.

```
nix-shell
python fetch.py
```

# Generate QR code for Catalyst

```
nix-shell
vit-kedqr -pin 1234 -input vote.sk
```

# Calculate community advisor rewards

To calculate the rewards for community advisors you need 3 csv files:
 * All proposals and reviews (file1.csv)(ideas in column A, community advisors email in column F)
 * Advisors ada payment address (file2.csv)(emails in column B, addresses in column C)
 * Non eligible advisors (file3.csv)(emails in column A)
Csv files can be easily exported/imported from/to spreadsheets, but you usually have to export every sheet in case there's more than one.
You also need to provide a random seed for the selection process and the total incentive (in $) available to advisors

The script will output a csv containing the funding (in $) to be sent to each advisor.

```
nix-shell
python calculate-advisors-rewards.py --seed=STRING --proposals=file1.csv --advisors=file2.csv --total-incentive=INT --non-eligible-advisors=file3.csv
```

### Selection process
The script seeds the random number generator using the provided value and then does the following for each proposal:
* read reviewers
* remove non eligible advisors from this list
* sort the list in alphabetic order
* select 3 random advisors from this list using Python `random.sample`. If there are less than 3 advisors for a proposal, select all of them.

If you want to reproduce the results, make sure you have the same files and use the same seed.
