#![feature(concat_bytes)]

pub mod g711;

rustler::init! {
    "Elixir.G711.Native",
    [
        g711::ulaw_to_linear,
        g711::linear_to_ulaw,
        g711::compress_ulaw_buffer,
        g711::expand_ulaw_buffer,
    ]
}