{ withSystem, ... }:
{
  flake.herculesCI = _: {
    ciSystems = [ "x86_64-linux" ];
    onPush.default.outputs =
      withSystem "x86_64-linux" (
        { config, ... }:
        {
          inherit (config.packages) rathole-server-image rathole-client-image;
        }
      );
  };
}
