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

# Calculate rewards results from valid tally data


```shell
nix-shell
python rewards.py --help
Usage: rewards.py [OPTIONS]

  Calculate catalyst rewards after tallying process. If both --proposals-
  path and --active-voteplan-path are provided data is loaded from the json
  files on those locations. Otherwise data is requested to the proper API
  endpoints pointed to the --vit-station-url option.

Options:
  --fund FLOAT                    [required]
  --conversion-factor FLOAT       [required]
  --output-file TEXT              [required]
  --threshold FLOAT               [default: 0.15]
  --output-format [csv|json]      [default: csv]
  --proposals-path TEXT
  --active-voteplan-path TEXT
  --vit-station-url TEXT          [default: https://servicing-
                                  station.vit.iohk.io]

  --install-completion [bash|zsh|fish|powershell|pwsh]
                                  Install completion for the specified shell.
  --show-completion [bash|zsh|fish|powershell|pwsh]
                                  Show completion for the specified shell, to
                                  copy it or customize the installation.

  --help                          Show this message and exit.


```

 Note, __finished tally data is expected__. This script would not be able to calculate anything if the tally data is incomplete.