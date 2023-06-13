module hello_world::level {
    struct Level has store, copy, drop {
        level:u8,
    }

    public fun get_level(data: &Level): u8 {
        return data.level
    }

    public entry fun new_level(): Level{
        Level {
            level:1
        }
    }
}