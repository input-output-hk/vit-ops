## Development

    nix.binaryCaches = [
      "https://hydra.iohk.io"
      "https://cache.nixos.org"
      "https://vit-ops.cachix.org"
    ];
    nix.binaryCachePublicKeys = [
      "hydra.iohk.io:f/Ea+s+dFdN+3Y/G+FDgSq+a5NEWhJGzdjvKNGv0/EQ="
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "vit-ops.cachix.org-1:LY84nIKdW7g1cvhJ6LsupHmGtGcKAlUXo+l1KByoDho="
    ];
    nix.extraOptions = ''
      experimental-features = nix-command flakes ca-references
    '';
    nix.package = pkgs.nixUnstable;

    environment.systemPackages = with pkgs; [
      neovim
      gitFull
    ];


### Github Access Token

* Github users who are in the IOHK team `jormungandr` have the ability to authenticate to the vit-ops project as developers.
  * If you are not in the `jormungandr` github team and require access to the vit-ops project, request team membership from the Mantis project team.

* To authenticate to the vit-ops project, use your github ID to create a personal access token for vit-ops if you don't already have one:
  * Login into github.com with your github work user id.
  * Navigate to the [Personal Access Tokens](https://github.com/settings/tokens) page of github.
  * Click "Generate new token".
  * Type "vit-ops" in the "Note" field.
  * Under the "Select scopes" section, check mark ONLY the "read:org" field described as "Read org and team membership, read org projects" under the "admin:org" area.
  * Click "Generate token".
  * Copy the new personal access token you are presented with as you will use it in a subsequent step and it is only shown once on the github webpage.
  * At any time, you can delete an existing vit-ops github token and create a new one to provide in the steps below.


### Vault Authentication

* From your nix development environment, obtain a vault token by supplying the following command with your github vit-ops personal access token when prompted:
    ```
    $ vault login -method github -path github-employees
    ```

* After logging into vault, if you need to see your vault token again or review information associated with your token, you can view it with the following command:
    ```
    $ vault token lookup
    ```

* To see only your vault token, without additional information, use the following command:
    ```
    $ vault print token
    ```


### Nomad Authentication

* After logging into vault, you can obtain a nomad token for the developer role with the following command:
    ```
    $ vault read -field secret_id nomad/creds/developer
    ```

* Optionally, you can export this token locally to have access to the nomad cli which will enable additional cli debugging capabilities.  For example:
    ```
    # Export the nomad developer token:
    $ export NOMAD_TOKEN="$(vault read -field secret_id nomad/creds/developer)"

    # Now the nomad cli becomes available.
    # The following are some example commands that may be useful:
    $ nomad status
    $ nomad status -namespace catalyst-dryrun leader-0
    $ nomad alloc logs $ALLOC_ID > leader-0-$ALLOC_ID.log
    $ nomad job -namespace catalyst-dryrun stop leader-0

    # etc.
    ```

* The nomad token is also used to authenticate to the vit-ops Nomad web UI at: https://nomad.vit.iohk.io/
  * In the upper right hand corner of the Nomad web UI, click "ACL Tokens".
  * Enter the nomad token in "Secret ID" field and click "Set Token".
  * You will now have access to the full Nomad web UI.


### Consul Authentication

* Optionally, a Consul token can be exported in order to use Consul templates, described below:
    ```
    export CONSUL_HTTP_TOKEN="$(vault read -field token consul/creds/developer)"
    ```




## Environments:

### Staging:

    Vote plan type: Private
    Vote period start: 2021-01-19T12:00:00Z
    Vote period end: 2021-01-21T12:00:00Z
    Tallying end: 2021-01-25T12:00:00Z

## Creating a vote plan

1. get proposals csv and sql_funds.csv from someone that exports it from ideascale
2. modify sql_funds.csv to have the correct dates
3. run the following:
    vitconfig \
      -fund csv-servicing-station/sql_funds.csv \
      -proposals csv-servicing-station/fund2-proposals.csv \
      -vote-start 2020-11-24T03:00:00Z \
      -vote-end 2020-11-25T00:00:00Z \
      -genesis-time 2020-11-23T18:00:00Z
    cp jnode_VIT_234069223/vote_plans/public_voteplan_b12005de8faa2cb14eecbc3f8051969cf407a6fd522f38fcc80861b3692064e5.json vote_plans/catalyst_dryrun.json
    vit-servicing-station-cli db init --db-url ./database.sqlite3
    vit-servicing-station-cli csv-data load \
      --db-url database.sqlite3 \
      --funds /home/sam/work/iohk/vit-ops/vit-scripts/scripts/jnode_VIT_234069223/vit_station/sql_funds.csv \
      --proposals /home/sam/work/iohk/vit-ops/vit-scripts/scripts/jnode_VIT_234069223/vit_station/sql_proposals.csv \
      --voteplans /home/sam/work/iohk/vit-ops/vit-scripts/scripts/jnode_VIT_234069223/vit_station/sql_voteplans.csv
    sha256sum database.sqlite3
4. upload database.sqlite3 to S3
5. update sha256 in `jobs/catalyst-dryrun-servicing-station.nix` for database.sqlite3
6. deploy with `nix run '.#nomadJobs.catalyst-dryrun-servicing-station.run'`

note that jnode_VIT_234069223 and the vote plan hash are autogenerated by the
vitconfig step and should be replaced by what it outputs. Ignore any errors as
long as those files are created.

sample expected output of vitconfig:

    vitconfig \
      -fund  csv-servicing-station/sql_funds.csv \
      -proposals csv-servicing-station/fund2-proposals.csv \
      -vote-start 2020-11-24T03:00:00Z \
      -vote-end 2020-11-25T00:00:00Z \
      -genesis-time 2020-11-23T18:00:00Z
    2020/11/23 21:05:17 Proposals File load took 454.264µs
    2020/11/23 21:05:17 Fund File load took 40.377µs
    2020/11/23 21:05:17 Working Directory: /home/sam/work/iohk/vit-ops/vit-scripts/scripts/jnode_VIT_234069223
    2020/11/23 21:05:17 VIT - Voteplan(s) data are dumped at (/home/sam/work/iohk/vit-ops/vit-scripts/scripts/jnode_VIT_234069223/vote_plans)
    2020/11/23 21:05:17 
    2020/11/23 21:05:17 VIT - Station data are dumped at (/home/sam/work/iohk/vit-ops/vit-scripts/scripts/jnode_VIT_234069223/vit_station)
    2020/11/23 21:05:17 
    2020/11/23 21:05:17 /build/go/src/github.com/input-output-hk/jorvit/cmd/vitconfig/vitconfig.go:863 [] -> open ./assets/extra_genesis_data.yaml: no such file or directory
## Submitting vote plan

    VOTE_PLAN=vote_plans/public_voteplan_dd18d9b808a3bce36da8fa32e1db10218bb50d6dcb687a8f3b90d2f03bfe0d49.json
    COMMITTEE_KEY=committee_03.sk
    COMMITTEE_ADDR=$(jcli address account $(jcli key to-public < "$COMMITTEE_KEY"))
    COMMITTEE_ADDR_COUNTER=$(jcli rest v0 account get "$COMMITTEE_ADDR" --output-format json|jq .counter)
    jcli certificate new vote-plan "$VOTE_PLAN" --output vote_plan.certificate
    jcli transaction new --staging vote_plan.staging
    jcli transaction add-account "$COMMITTEE_ADDR" 0 --staging vote_plan.staging
    jcli transaction add-certificate $(< vote_plan.certificate) --staging vote_plan.staging
    jcli transaction finalize --staging vote_plan.staging
    jcli transaction data-for-witness --staging vote_plan.staging > vote_plan.witness_data
    jcli transaction make-witness --genesis-block-hash $(jcli genesis hash < block0.bin) --type account --account-spending-counter "$COMMITTEE_ADDR_COUNTER" $(< vote_plan.witness_data) vote_plan.witness "$COMMITTEE_KEY"
    jcli transaction add-witness --staging vote_plan.staging vote_plan.witness
    jcli transaction seal --staging vote_plan.staging
    jcli transaction auth --staging vote_plan.staging --key "$COMMITTEE_KEY"
    jcli transaction to-message --staging vote_plan.staging > vote_plan.fragment
    jcli rest v0 message post --file vote_plan.fragment
    jcli rest v0 vote active plans get


## Tally votes

    VOTE_PLAN_ID=$(jcli rest v0 vote active plans get --output-format json|jq '.[0].id')
    COMMITTEE_KEY=committee_03.sk
    COMMITTEE_ADDR=$(jcli address account $(jcli key to-public < "$COMMITTEE_KEY"))
    COMMITTEE_ADDR_COUNTER=$(jcli rest v0 account get "$COMMITTEE_ADDR" --output-format json|jq .counter)
    jcli certificate new vote-tally --vote-plan-id "$VOTE_PLAN_ID" --output vote_tally.certificate
    jcli transaction new --staging vote_tally.staging
    jcli transaction add-account "$COMMITTEE_ADDR" 0 --staging vote_tally.staging
    jcli transaction add-certificate $(< vote_tally.certificate) --staging vote_tally.staging
    jcli transaction finalize --staging vote_tally.staging
    jcli transaction data-for-witness --staging vote_tally.staging > vote_tally.witness_data
    jcli transaction make-witness --genesis-block-hash $(jcli genesis hash < block0.bin) --type account --account-spending-counter "$COMMITTEE_ADDR_COUNTER" $(< vote_tally.witness_data) vote_tally.witness "$COMMITTEE_KEY"
    jcli transaction add-witness --staging vote_tally.staging vote_tally.witness
    jcli transaction seal --staging vote_tally.staging
    jcli transaction auth --staging vote_tally.staging --key "$COMMITTEE_KEY"
    jcli transaction to-message --staging vote_tally.staging > vote_tally.fragment
    jcli rest v0 message post --file vote_tally.fragment
    jcli rest v0 vote active plans get
