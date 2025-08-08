use pulldown_cmark::{Event, Options, Parser, Tag, TagEnd};
use regex::Regex;

type Table = Vec<Vec<String>>;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct Position {
    pub line: usize,
    pub column: usize,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct Span {
    pub start: Position,
    pub end: Position,
}

#[derive(Debug, Clone)]
pub struct TableInfo {
    pub table: Table,
    pub position: Position,
    pub span: Span,
}

fn offset_to_position(markdown: &str, offset: usize) -> Position {
    let mut line = 1;
    let mut last_newline_offset = 0;
    for (i, c) in markdown.char_indices() {
        if i >= offset {
            break;
        }
        if c == '\n' {
            line += 1;
            last_newline_offset = i + 1;
        }
    }
    let column = markdown[last_newline_offset..offset].chars().count() + 1;
    Position { line, column }
}

pub fn extract_all_tables(markdown: &str) -> Vec<(Table, Position)> {
    let mut options = Options::empty();
    options.insert(Options::ENABLE_TABLES);
    let parser = Parser::new_ext(markdown, options);

    let mut tables = Vec::new();
    let mut current_table = Vec::new();
    let mut curr_row = Vec::new();
    let mut in_table = false;
    let mut table_start_offset = 0;

    for (event, range) in parser.into_offset_iter() {
        match event {
            Event::Start(Tag::Table(_)) => {
                in_table = true;
                current_table.clear();
                table_start_offset = range.start;
            }
            Event::End(TagEnd::Table) => {
                if in_table {
                    let position = offset_to_position(markdown, table_start_offset);
                    tables.push((current_table.clone(), position));
                    in_table = false;
                }
            }
            Event::Start(Tag::TableRow) if in_table => {
                curr_row.clear();
            }
            Event::End(TagEnd::TableRow) if in_table => {
                current_table.push(curr_row.clone());
            }
            Event::Start(Tag::TableCell) if in_table => {
                curr_row.push(String::new());
            }
            Event::Text(text) if in_table => {
                if let Some(cell) = curr_row.last_mut() {
                    cell.push_str(&text);
                }
            }
            _ => (),
        }
    }
    tables
}

pub fn extract_all_tables_with_spans(markdown: &str) -> Vec<TableInfo> {
    let lines: Vec<&str> = markdown.lines().collect();
    let mut tables = Vec::new();
    let table_regex = Regex::new(r"^\s*\|.*\|\s*$").unwrap();
    let separator_regex = Regex::new(r"^\s*\|[\s:|-]*\|\s*$").unwrap();

    let mut i = 0;
    while i < lines.len() {
        if table_regex.is_match(lines[i]) {
            let start_line = i + 1;
            let mut table = Vec::new();
            let mut end_line = start_line;

            // Extract table rows
            while i < lines.len() && table_regex.is_match(lines[i]) {
                let row = parse_table_row(lines[i]);
                table.push(row);
                end_line = i + 1;
                i += 1;
            }

            if table.len() >= 2 {
                tables.push(TableInfo {
                    table,
                    position: Position {
                        line: start_line,
                        column: 1,
                    },
                    span: Span {
                        start: Position {
                            line: start_line,
                            column: 1,
                        },
                        end: Position {
                            line: end_line,
                            column: lines[end_line - 1].len(),
                        },
                    },
                });
            }
            continue;
        }
        i += 1;
    }

    tables
}

fn parse_table_row(line: &str) -> Vec<String> {
    line.trim()
        .strip_prefix('|')
        .unwrap_or(line.trim())
        .strip_suffix('|')
        .unwrap_or(line.trim())
        .split('|')
        .map(|cell| cell.trim().to_string())
        .collect()
}

fn calculate_col_widths(table: &Table) -> Vec<usize> {
    if table.is_empty() {
        return Vec::new();
    }
    let mut widths: Vec<usize> = table[0].iter().map(|header| header.len()).collect();
    for row in table.iter() {
        for (i, cell) in row.iter().enumerate() {
            if i < widths.len() {
                widths[i] = widths[i].max(cell.len());
            }
        }
    }
    widths
}

fn format_table(table: &Table, widths: &[usize]) -> String {
    if table.is_empty() {
        return String::new();
    }

    let mut formatted = String::new();

    // Header row
    for (i, header_cell) in table[0].iter().enumerate() {
        let padded_cell = format!("{:<width$}", header_cell, width = widths[i]);
        formatted.push_str(&format!("| {} ", padded_cell));
    }
    formatted.push_str("|\n");

    // Separator row
    for width in widths {
        let separator = "-".repeat(*width);
        formatted.push_str(&format!("|:{}-", separator));
    }
    formatted.push_str("|\n");

    // Data rows
    for row in table.iter().skip(1) {
        for (i, cell) in row.iter().enumerate() {
            if i < widths.len() {
                let padded_cell = format!("{:<width$}", cell, width = widths[i]);
                formatted.push_str(&format!("| {} ", padded_cell));
            }
        }
        formatted.push_str("|\n");
    }
    formatted
}

pub fn format_all_tables_in_markdown(markdown: &str) -> String {
    let tables = extract_all_tables_with_spans(markdown);
    let mut result = markdown.to_string();

    for table_info in tables.iter().rev() {
        let formatted = format_table(&table_info.table, &calculate_col_widths(&table_info.table));
        let lines: Vec<&str> = result.lines().collect();

        let mut new_lines = Vec::new();
        for (i, line) in lines.iter().enumerate() {
            let line_num = i + 1;
            if line_num < table_info.span.start.line || line_num > table_info.span.end.line {
                new_lines.push(line.to_string());
            } else if line_num == table_info.span.start.line {
                new_lines.extend(formatted.lines().map(|s| s.to_string()));
            }
        }

        result = new_lines.join("\n");
    }

    result
}

pub fn is_cursor_in_table(markdown: &str, cursor_line: usize, _cursor_col: usize) -> bool {
    let tables = extract_all_tables_with_spans(markdown);

    for table_info in &tables {
        if cursor_line >= table_info.span.start.line && cursor_line <= table_info.span.end.line {
            return true;
        }
    }
    false
}

pub fn format_table_at_position(markdown: &str, cursor_line: usize, _cursor_col: usize) -> String {
    let tables = extract_all_tables_with_spans(markdown);

    for table_info in &tables {
        if cursor_line >= table_info.span.start.line && cursor_line <= table_info.span.end.line {
            return format_all_tables_in_markdown(markdown);
        }
    }

    markdown.to_string()
}

pub fn get_formatted_tables(markdown: &str) -> Vec<(String, Span)> {
    extract_all_tables_with_spans(markdown)
        .iter()
        .map(|table_info| {
            (
                format_table(&table_info.table, &calculate_col_widths(&table_info.table)),
                table_info.span,
            )
        })
        .collect()
}
