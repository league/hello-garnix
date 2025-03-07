{
  description = "A very basic flake";

  inputs.gcipher = {
    url =
      "https://sourceforge.net/projects/gcipher/files/gcipher/1.1/gcipher-1.1.tar.gz";
    flake = false;
  };

  outputs = inputs@{ self, nixpkgs, ... }:
    let
      inherit (nixpkgs) lib;

      eachSystem = lib.genAttrs [ "x86_64-linux" ];

      pkgs = eachSystem (system:
        import nixpkgs {
          inherit system;
          overlays = [ self.overlays.gcipher ];
        });
    in {

      overlays.gcipher = final: prev: {
        gcipher-cli = final.callPackage
          ({ stdenvNoCC, makeWrapper, python, lib }:
            stdenvNoCC.mkDerivation rec {
              name = "gcipher";
              version = "1.2";
              src = inputs.gcipher;
              # Always run command-line version
              patchPhase = ''
                substituteInPlace src/MainCLI.py --replace 'len(argv) > 1' 'True'
              '';
              compilePhase = "";
              buildInputs = [ makeWrapper python ];
              installPhase = ''
                mkdir -p $out/{bin,share/{man/man1,doc/${name},${name}}}
                cp CONTRIB README $out/share/doc/${name}
                cp gcipher.1 $out/share/man/man1
                cp -r src/{gcipher,MainCLI.py,Const.py,AutomaticClass.py,cipher} $out/share/${name}
                makeWrapper $out/share/${name}/gcipher $out/bin/gcipher
              '';
              meta = {
                maintainers = [ lib.maintainers.league ];
                platforms = lib.platforms.all;
                mainProgram = "gcipher";
              };
            }) { };
      };

      nixosConfigurations.starfish = lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          ({ modulesPath, pkgs, ... }: {
            imports = [ "${modulesPath}/virtualisation/qemu-vm.nix" ];
            environment.systemPackages = with pkgs; [
              hello
              gcipher-clo
              neofetch
            ];
          })
          {
            users.mutableUsers = false;
            users.users.root.hashedPassword =
              "$6$AaW9nlwiwN/a$WE8VF41jDww37XPXN3m8aLEJ8DtGBsy/pLZaHKoJHXhja6cqtvCptPV9ZM1dpG4ng4GIVnHmfPqBsflo4M5Di.";
            nixpkgs.overlays = [ self.overlays.gcipher ];
            networking.hostName = "starfish";
          }
        ];
      };

      packages = eachSystem (system: {
        inherit (pkgs.${system}) gcipher-cli;

        docs-site = pkgs.${system}.linkFarm "docs-site" [{
          name = "postgresql";
          path =
            "${pkgs.${system}.postgresql.doc}/share/doc/postgresql/html";
        }];

        hello-garnix = pkgs.${system}.stdenv.mkDerivation {
          name = "hello-garnix";
          unpackPhase = ":";
          buildPhase = ''
            echo "Just building some things; don't especially mind me"
            cat > an-executable <<EOF
            echo "Hello from an executable!"
            EOF
            chmod +x an-executable
          '';
          checkPhase = ''
            echo "Looking around to see if anything is amiss.."
            OUTPUT=$(./an-executable)
            if [ "$OUTPUT" != "Hello from an executable!" ]; then
              echo "Test failed!"
              exit 1
            fi
          '';
          installPhase = ''
            mkdir -p $out/bin
            cp an-executable $out/bin/
          '';
          doCheck = true;
        };
      });
    };
}
