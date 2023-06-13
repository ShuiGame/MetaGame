module hello_world::gift {
    use std::string;
    struct Gift has store, copy, drop {
        gift:string::String,
    }

    public fun get_gift(data: &Gift): string::String {
        return data.gift
    }

    public entry fun new_Gift(): Gift{
        Gift {
            gift:string::utf8(b"none")
        }
    }
}