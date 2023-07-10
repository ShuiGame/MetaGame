module shui_module::tree_of_life {
    use sui::object::{Self, UID};
    use sui::tx_context::{Self, TxContext};
    use sui::transfer;
    use sui::pay;
    use sui::coin::{Self, Coin, destroy_zero};
    use std::vector::{Self};
    use shui_module::shui::{SHUI};
    use std::string;
    use sui::hash;
    use sui::balance::{Self, Balance};
    use sui::table::{Self, Table};
    use sui::bcs;
    use sui::clock::{Self, Clock};

    const DAY_IN_MS: u64 = 86_400_000;
    const ERR_INTERVAL_TIME_ONE_DAY:u64 = 0x001;

    struct Tree_of_life has key, store {
        id:UID,
        level:u16,
        exp:u16,
    }

    struct TreeGlobal has key {
        id: UID,
        balance_SHUI: Balance<SHUI>,
        creator: address,
        water_down_last_time_records: Table<address, u64>,
        water_down_person_exp_records: Table<address, u64>,
    }

    struct WaterElement has key, store {
        id:UID,
        // 0,1,2,3,4
        typeId: string::String,
    }

    struct Fruit has key, store {
        id:UID,
    }

    public entry fun mint(ctx:&mut TxContext) {
        let tree = Tree_of_life {
            id:object::new(ctx),
            level:1,
            exp:0
        };
        transfer::public_transfer(tree, tx_context::sender(ctx));
    }

    public entry fun water_down(global: &mut TreeGlobal, amount:u64, coins:vector<Coin<SHUI>>, clock: &Clock, ctx:&mut TxContext, ) {
        // interval time should be greater than 1 days
        let sender = tx_context::sender(ctx);
        let now = clock::timestamp_ms(clock);
        if (table::contains(&global.water_down_last_time_records, sender)) {
            let lastWaterDownTime = *table::borrow(&global.water_down_last_time_records, sender);
            assert!((now - lastWaterDownTime) > DAY_IN_MS, ERR_INTERVAL_TIME_ONE_DAY);
        } else {
            table::add(&mut global.water_down_last_time_records, sender, now);
        };
        let merged_coin = vector::pop_back(&mut coins);
        pay::join_vec(&mut merged_coin, coins);
        assert!(coin::value(&merged_coin) >= amount, 1);
        let balance = coin::into_balance<SHUI>(
            coin::split<SHUI>(&mut merged_coin, amount, ctx)
        );
        balance::join(&mut global.balance_SHUI, balance);
        if (coin::value(&merged_coin) > 0) {
            transfer::public_transfer(merged_coin, tx_context::sender(ctx))
        } else {
            destroy_zero(merged_coin)
        };

        // record the time and exp
        if (table::contains(&global.water_down_person_exp_records, sender)) {
            let last_exp = *table::borrow(&global.water_down_person_exp_records, sender);
            if (last_exp == 4) {
                transfer::public_transfer(
                    Fruit {
                        id:object::new(ctx)
                    },
                    tx_context::sender(ctx)
                );
                table::remove(&mut global.water_down_person_exp_records, sender);
                table::add(&mut global.water_down_person_exp_records, sender, 0);
            } else {
                table::remove(&mut global.water_down_person_exp_records, sender);
                table::add(&mut global.water_down_person_exp_records, sender, last_exp + 1);
            }
        } else {
            table::add(&mut global.water_down_person_exp_records, sender, 1);
        };
    }

    fun get_random_exp(amount:u64) :u16 {
        let u:u16 = 2;
        if (amount > 8) {
          return u
        };
        u
    }

    // fun get_random_element() :u64 {
    //     let random = bytes_to_u64(seed(ctx)) % 5;
    //     random
    // }

    fun bytes_to_u64(bytes: vector<u8>): u64 {
        let value = 0u64;
        let i = 0u64;
        while (i < 8) {
            value = value | ((*vector::borrow(&bytes, i) as u64) << ((8 * (7 - i)) as u8));
            i = i + 1;
        };
        return value
    }

    fun seed(ctx: &mut TxContext): vector<u8> {
        let ctx_bytes = bcs::to_bytes(ctx);
        let uid = object::new(ctx);
        let uid_bytes: vector<u8> = object::uid_to_bytes(&uid);
        object::delete(uid);

        let info: vector<u8> = vector::empty<u8>();
        vector::append<u8>(&mut info, ctx_bytes);
        vector::append<u8>(&mut info, uid_bytes);
        let hash: vector<u8> = hash::keccak256(&info);
        hash
    }
}