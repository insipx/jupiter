{ self, ... }:
{
  herculesCI = {
    ciSystems = [ "x86_64-linux" ];
    onPush.default.outputs = {
      inherit (self.packages.x86_64-linux) rathole-server-image rathole-client-image;
    };
  };
}
