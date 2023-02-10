# Password Manager Dotfiles Manager

This is designed to be a super-barebones dotfile manager that stores all of your dotfiles as secure notes in your password manager of choice.
Simple -- lots of other good options out there but honestly I don't want most of the capabilities that they come with.
Secure -- you already trust your password manager to store secure values and to synchronize them between computers.
Private -- honestly, even with encryption or templating, I don't really want my dotfiles in a public git repo, and putting them in a private repo adds another layer of authentication to the setup process.
Multi-machine -- again, your password manager provides this for you already.

## Installing

Copy that curl + tar command from github-dev-init

// Hm... there are going to be a bunch of separate scripts in here for different password managers.. should the "install" process install only the one you want?

Optional: ln -s whatever to an appropriate location on your PATH

## Configuring

XDG note

Setting the vault (personal vs. work, default vs. shared) -- This will use defaults!
Setting the folder in your password manager.
It will default to using 
If you want to use a different folder name than the default in your password manager, set it in ~/whatever/pmdm.env (or just set it in your environment under `PMDM_SOMEWHASSIT`).

pmdm.env
pmdm-bitwarden.env


## Usage

pmdm config (interactive)
  // what base directory? (default home) (files outside of this directory will expect the same full path on all systems), what password manager, okay make sure the CLI is installed, any "extra args" (self-hosted BW for instance), okay log in to it, what vault, what folder/tag
pmdm add <path> (add a new file AND push to upstream)
pmdm sync (interactive)
pmdm sync --prefer-upstream
pmdm sync --prefer-local
pmdm rm <path>
// TODO: difference between removing it from the local filesystem/unlinking it and purging it from the password manager?
// TODO: what does unlinking look like? probably an entry in pmdm.env? (nah, a new local-only "files-to-skip.txt" or some such)

Note: this won't warn you about any conflicts when pushing, it'll just overwrite with whichever you specify

Note: These instructions assume that you have symlinked the script such that it is available on your path.
If you have not, simply replace `pmdm` with `~/.local/bin/password-manager-dotfiles-manager.sh` in the commands.

## Dependencies

Only whatever password manager you choose and `bash` on a unix-like system are required to use this.

(also curl + tar if you want to use the one-line install)

// TODO: test it on a bunch of platforms and list those here


