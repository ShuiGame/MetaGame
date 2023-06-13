module hello_world::race {
    use std::string;
    struct Race has store, copy, drop {
        category:string::String,
        desc:string::String,
    }

    public fun category(data: &Race): string::String {
        return data.category
    }
}