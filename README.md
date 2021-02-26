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
  * If you are not in the `jormungandr` github team and require access to the vit-ops project, request team membership from the Jormungandr project team.

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

## Deployments

### Testnet Snapshot

Some arguments below may differ over time.

    $ bitte ssh "$(cue -t job=db-sync-testnet dbSyncInstance)"
    $ nix run github:input-output-hk/voting-tools#voting-tools -- \
        genesis \
        --testnet-magic 1097911063 \
        --db cexplorer \
        --db-user cexplorer \
        --db-host /var/lib/nomad/alloc/9aab6f67-635f-e066-a823-1fde40ffee47/alloc \
        --out-file out \
        --scale 1000000 \
        --slot-no 18433484

### Mainnet Snapshot

    $ bitte ssh "$(cue -t job=db-sync-mainnet dbSyncInstance)"
    $ nix run github:input-output-hk/voting-tools/master#voting-tools -- \
        genesis \
        --mainnet \
        --db cexplorer \
        --db-user cexplorer \
        --db-host /var/lib/nomad/alloc/54a497e0-bc1e-28af-8b15-21edaff781c1/alloc/ \
        --out-file genesis.json

### Testnet Rewards

Some arguments below may differ over time.

    $ bitte ssh "$(cue -t job=db-sync-testnet dbSyncInstance)"
    $ nix run github:input-output-hk/voting-tools -- \
        rewards \
        --testnet-magic 1097911063 \
        --db cexplorer \
        --db-user cexplorer \
        --db-host /var/lib/nomad/alloc/9aab6f67-635f-e066-a823-1fde40ffee47/alloc \
        --slot-no 18433484 \
        --total-rewards 500000000000 \
        --out-file rewards

### Stopping dryrun

    $ ./deploy.rb stop

### Starting dryrun

    $ ./deploy.rb run

### Resetting dryrun

You'll need a database.sqlite3 and block0.bin file in the current directory.
Afterwards you can run the deploy script:

    $ ./deploy.rb reset

### Get Vote Plan to prepare for tallying

    $ bitte ssh 10.24.29.200
    $ mkdir -p output
    $ cp -r /var/lib/nomad/alloc/957d45be-db9d-d8f6-9dea-e81694b48442/jormungandr/local/storage .
    $ nix run github:input-output-hk/catalyst-fund-archive-tool ./storage ./output

### Tally votes

    $ ./scripts/tally.sh


## Checklist for Dryrun

- [ ] Make Snapshot
- [ ] Send generated funds data to person in charge of generating the Genesis and DB
- [ ] Receive the new block0.bin and database.sqlite3
- [ ] Reset the namespace using the above instructions
