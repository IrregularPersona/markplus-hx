use steel::{
    SteelVal, declare_module,
    steel_vm::{
        ffi::{FFIModule, RegisterFFIFn},
        register_fn,
    },
};

mod checklist;
mod table;

declare_module!(create_module);

const MODULE: &str = "steel/markplus-hx";

fn create_module() -> FFIModule {
    let mut module = FFIModule::new(MODULE);

    module
        .register_fn("is-checkbox?", checklist::check_regex)
        .register_fn("change-checkbox-state!", checklist::toggle_checklist);
    module
}

fn has_table_elements(buffer: &str) -> bool {
    let table = table::extract_all_tables(buffer);
    !table.is_empty()
}

fn format_tables_in_buffer(buffer: &str) -> String {
    table::format_all_tables_in_markdown(buffer)
}

fn is_table_line(line: &str) -> bool {
    let trimmed = line.trim();
    (trimmed.starts_with('|') && trimmed.ends_with('|')) || trimmed.matches('|').count() >= 2
}

fn format_current_table_at_cursor(buffer: &str, line: usize, col: usize) -> String {
    table::format_table_at_position(buffer, line, col)
}

fn detect_table_at_cursor(buffer: &str, line: usize, col: usize) -> bool {
    table::is_cursor_in_table(buffer, line, col)
}
