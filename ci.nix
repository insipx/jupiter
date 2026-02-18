_: {
  perSystem =
    { self', ... }:
    {
      herculesCI = {
        onPush.default = {
          outputs = _: {
            inherit (self'.packages) rathole-server-image rathole-client-image;
          };
        };
      };
    };
}
