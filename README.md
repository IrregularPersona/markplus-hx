# markplus-hx

markplus-hx is a plugin for [Helix](https://github.com/helix-editor/helix) which attempts to provide built-in functions to allow users to be more interactive with their Markdown files. Currently, it is in its most minimal state.

## Installation

Follow the instructions to install Helix on the plugin [branch](https://github.com/mattwparas/helix/blob/steel-event-system/STEEL.md)

Then, you can install the plugin using:

```sh
forge pkg install --git https://github.com/IrregularPersona/markplux-hx.git
```

Once finished installing, you need to add the following to the auto-generated `init.scm` file in your Helix config directory:

```scheme
(require "markplus-hx/markplus-hx.scm")
```

Afterwards, you can update your `config.toml` to use the functions from the plugin like this:

```toml
[keys.normal]
A-h = ":create-itemized-section!"
A-j = ":convert-to-link!"
A-k = ":create-codeblock!"
A-l = ":checkbox-toggle!"
```

### Current Features

- [X] Bindable checklisting
- [X] Bindable codeblocks (Non-autocomplete)
- [X] Bindable link creation
- [X] Selection-based Itemizing

### Coming Features
- [ ] Markdown mode(?)
- [ ] Dynamic Tables
- [ ] (Maybe) Folding per lists or even header?

