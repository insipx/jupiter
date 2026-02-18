{ ... }:
{
  flake.herculesCI = _: {
    ciSystems = [ "x86_64-linux" ];
    onPush.default.outputs =
      { self', ... }:
      {
        inherit (self'.packages) rathole-server-image rathole-client-image;
      };
  };
}
