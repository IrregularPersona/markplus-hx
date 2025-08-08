use steel::{
    declare_module,
    steel_vm::{
        ffi::{FFIModule, RegisterFFIFn},
        register_fn,
    },
};

use regex::Regex;

declare_module!(create_module);

const MODULE: &str = "steel/markplus-hx";

fn create_module() -> FFIModule {
    let mut module = FFIModule::new(MODULE);

    module
        .register_fn("is-checkbox?", checklist_regex)
        .register_fn("change-checkbox-state!", toggle_checklist)
        .register_fn("itemize-text!", itemize_text)
        .register_fn("create-link!", create_link);
    module
}

fn checklist_regex(text: &str) -> bool {
    let re = Regex::new(r"- \[( |x|X)\]").unwrap();
    re.is_match(text)
}

fn toggle_checklist(line: &str) -> String {
    let re = Regex::new(r"- \[( |x|X)\]").unwrap();

    re.replace(line, |capture: &regex::Captures| {
        match &capture[1] {
            " " => "- [X]",
            "x" => "- [ ]",
            "X" => "- [ ]",
            _ => &capture[0],
        }
        .to_string()
    })
    .to_string()
}

fn create_link(selection: &str) -> String {
    let trimmed = selection.trim();
    format!("[{}]()", trimmed)
}

fn itemize_text(text: &str) -> String {
    let lines: Vec<&str> = text
        .lines()
        .filter(|line| !line.trim().is_empty())
        .collect();

    if lines.is_empty() {
        return String::new();
    }

    let mut result = Vec::new();

    for line in lines {
        let indent_level = line.len() - line.trim_start().len();
        let content = line.trim();

        let bullet_level = indent_level / 2;
        let indent = "  ".repeat(bullet_level);

        result.push(format!("{}- {}", indent, content));
    }

    result.join("\n")
}
