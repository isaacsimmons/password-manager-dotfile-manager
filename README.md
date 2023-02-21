# Password Manager.env

A simple command line utility to sync configuration files holding local development secrets to a password manager.

Easily restore your development environment on a new machine, backup the API keys etc that you need to have a functioning local development environment. Synchronize those changes between multiple machines if applicable.

Functions similarly to a relatively barebones dotfiles manager.
Relatively barebones in terms of functionality.
Not a full git repository, no history or branching.
No templating, encryption, or OS specific flags.

However, by relying on your password manager for storage, it gets a couple of things for free.
* Synchronized. Multi-machine sync is baked in.
* Secure. Secure storage for secrets -- that's what you're already using it for.
* Private. Even with encryption or templating, I don't really want my dotfiles in a public git repo, and storing them in a private repo adds another level of authentication to the process.

If you're just storing your .vimrc or whatever that's fine -- share away, but my development environments often contain secrets that I don't want to just throw into a git repository.

# Dependencies

This should be usable with minimal dependencies

* apt-based linux (debian, ubuntu, etc) or macOS (do I even need this restriction??)
* bash
* md5sum

In addition, to use the one-line install script below, you will need:

* curl
* tar

Also depending on the password manager you pick -- bitwarden CLI + jq

## Installing

    mkdir -p ~/.local/share/dev-init && curl -SsL https://api.github.com/repos/isaacsimmons/password-manager-dotfile-manager/tarball/main | tar xz --strip-components=1 -C ~/.local/share/password-manager-dotfile-manager

TODO: add "install latest release" command too, use github releases

Optional: symlink this somewhere on your path

    ln -s ~/.local/share/password-manager-dotfile-manager/pmdm.sh ~/bin/pmdm

You can also clone the repo instead of using the one-liner install.

## Configuring

Setting the vault (personal vs. work, default vs. shared) -- This will use defaults!
Setting the folder in your password manager.
It will default to using 
If you want to use a different folder name than the default in your password manager, set it in ~/whatever/pmdm.env (or just set it in your environment under `PMDM_SOMEWHASSIT`).

pmdm.env

## Usage

pmdm config (interactive)
  // what base directory? (default home) (files outside of this directory will expect the same full path on all systems), what password manager, okay make sure the CLI is installed, any "extra args" (self-hosted BW for instance), okay log in to it, what vault, what folder/tag
pmdm add <path> (add a new file or update an existing file in password manager)
pmdm sync (interactive)
pmdm sync --prefer-upstream
pmdm sync --prefer-local
pmdm rm <path>
// TODO: difference between removing it from the local filesystem/unlinking it and purging it from the password manager?
// TODO: what does unlinking look like? probably an entry in pmdm.env? (nah, a new local-only "files-to-skip.txt" or some such)

Note: this won't warn you about any conflicts when pushing, it'll just overwrite with whichever you specify

Note: These instructions assume that you have symlinked the script such that it is available on your path.
If you have not, simply replace `pmdm` with `~/.local/config/password-manager-dotfiles-manager/pmdm.sh` in the commands.

## Configuration (advanced)

Instead of using the `pmdm config` command, you can also manually edit the config file in `~/.config/password-manager-dotfile-manager/pmdm.env`, or simply set the relevant values in your shell environment.

Note: this follows the [XDG Base Directory Specification](https://specifications.freedesktop.org/basedir-spec/basedir-spec-latest.html) for config files and the default config folder can be overridden with the `$XDG_CONFIG_HOME` environment variable.
