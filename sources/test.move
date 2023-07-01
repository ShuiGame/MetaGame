module shui_module::api {
    use std::string;
    use sui::tx_context::{TxContext};
    use sui::transfer;
    use sui::object::{Self, UID};

    const ERROR_MUST_ADMIN: u64 = 102;

    const PHASEONE: u64 = 10;
    const PHASETWO: u64 = 125;

    struct Global has key {
        id:UID,
        field1: u64,
        field2: u16,
        field3: string::String,
    }

    struct API has drop{}

    struct StageInfo has key, store {
        id:UID,
        phases: u64
    }

    fun init(witness: API, ctx:&mut TxContext) {
        // let (burnCapability, freezeCapability, mintCapability) = coin::initialize<SHUI>(
        //     sender,
        //     string::utf8(b"shui"),
        //     string::utf8(b"shui"),
        //     8,
        //     true);
        let stageInfo = StageInfo {
            id:object::new(ctx),
            phases: 1
        };
        let glo = Global {
            id:object::new(ctx),
            field1: 16,
            field2: 16,
            field3: string::utf8(b"2")
        };
        transfer::share_object(glo);
        transfer::share_object(stageInfo);
    }

    public entry fun fun1() : u64 {
        1
    }

    public entry fun fun2() : string::String {
        string::utf8(b"test")
    }

    
    public entry fun fun3() : string::String {
        string::utf8(b"test")
        // tx_context::sender(ctx)
    }

    public entry fun fun4(global:&Global) : u64 {
        global.field1
    }

    public entry fun fun5(global:&mut Global, param:u16) : u16 {
        global.field2 = param;
        param + 1
    }
}