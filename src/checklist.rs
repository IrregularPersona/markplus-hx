use regex::Regex;

pub fn toggle_checklist(line: &str) -> String {
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

pub fn check_regex(text: &str) -> bool {
    let re = Regex::new(r"- \[( |x|X)\]").unwrap();
    re.is_match(text)
}
