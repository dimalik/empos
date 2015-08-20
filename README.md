# Emacs Paper Online Search

Emacs wrapper for pyopl (python online paper locator) to search and fetch scientific citations online and add them to a bib file.

## Installation

To try it out, download the latest version of `empos.el` from github and add to your `.emacs`

```elisp
(add-to-list 'load-path "/path/to/empos")           ; comment if empos.el is in standard load path
(require 'empos)

(setq empos-available-engines '("arxiv" "crossref"))
(setq empos-favorite-engines '("crossref"))         ; comment for all available
(setq empos-bib-file "path/to/bibliography.bib")
(setq empos-secondary-bib "path/to/a/folder")
```

1. `empos-available-engines` should contain engines that have been installed in pyopl.
1. `empos-favorite-engines` contains the engines to be used. Note this is a custom variable and can be set through customization.
1. `empos-bib-file` is the (absolute) path to the master bibliography file in which the references are appended.
1. `empos-secondary-bib` is the (absolute) path to a folder in which the citations are going to be added.

## Usage

### Short story

`M-x empos-search RET your-query RET`

### Longer version

The extension is essentially a wrapper for pyopl written for emacs. It works by calling pyopl with arguments specified in emacs, displaying the results in a separate buffer and saving the references in a specified location.

The location of the `pyopl` executable is considered to be global (i.e, it can be invoked like this:

 ```bash
 pyopl "you talkin to me"
 ```
 
In case something goes wrong and this does not work (might be the case in virtualenvs), you can respecify the variable `pyopl-path`.  The engines which are used are specified in `empos-favorite-engines` which is a list of strings containing the names of the engines. If no such variable is declared then the search is done on all available engines defined in `empos-available-engines`.

The actual search is carried by an interactive function `empos-search` displaying its output on a new buffer defining an minor mode called `empos-mode` to ensure better interaction.

Upon hitting <RET> the function `empos-get-identifier` is called using a regex to fetch the relevant id and engine and calling the `pyopl` executable again, this time in fetch mode.

