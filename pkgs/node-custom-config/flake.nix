{
  outputs = { ... }: {
    nixosModules.cardano-node = {
      services.cardano-node = {
        stateDir = "/persist";
        socketPath = "/alloc/node.socket";
      };
    };
  };
}
