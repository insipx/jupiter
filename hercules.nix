{ withSystem, ... }:
{
  flake.herculesCI =
    { ... }:
    {
      ciSystems = [ "x86_64-linux" ];
      onPush.default.outputs = withSystem "x86_64-linux" (
        { self', ... }:
        {
          inherit (self'.packages) rathole-server-image rathole-client-image;
        }
      );
    };
}
