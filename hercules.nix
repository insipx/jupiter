{ withSystem, ... }:
{
  flake.herculesCI = _: {
    onPush.default.outputs = withSystem "x86_64-linux" (
      { self', ... }:
      {
        inherit (self'.packages) rathole-server-image rathole-client-image;
      }
    );
  };
}
