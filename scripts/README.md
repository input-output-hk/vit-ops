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
