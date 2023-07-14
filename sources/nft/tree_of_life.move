module shui_module::tree_of_life {
    use sui::object::{Self, UID};
    use sui::tx_context::{Self, TxContext};
    use sui::transfer;
    use sui::pay;
    use sui::coin::{Self, Coin, destroy_zero};
    use std::vector::{Self};
    use shui_module::shui::{SHUI};
    use sui::hash;
    use sui::balance::{Self, Balance};
    use sui::table::{Self, Table};
    use sui::bcs;
    use sui::clock::{Self, Clock};
    use shui_module::items;
    use shui_module::metaIdentity::{MetaIdentity, get_items};
    use std::string;

    const DAY_IN_MS: u64 = 86_400_000;
    const ERR_INTERVAL_TIME_ONE_DAY:u64 = 0x001;
    const ERR_WRONG_COMBINE_NUM:u64 = 0x002;
    const ERR_WRONG_TYPE:u64 = 0x003;

    // 0-4: fragment   100-200:water element
    const ITEM_TYPE:u64 = 0;

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

    struct WaterElement has store {}

    struct Fragment has store {}

    struct Fruit has store {}

    public entry fun mint(ctx:&mut TxContext) {
        let tree = Tree_of_life {
            id:object::new(ctx),
            level:1,
            exp:0
        };
        transfer::public_transfer(tree, tx_context::sender(ctx));
    }

    public entry fun water_down(global: &mut TreeGlobal, meta:&mut MetaIdentity, amount:u64, coins:vector<Coin<SHUI>>, clock: &Clock, ctx:&mut TxContext) {
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
                items::store_item(get_items(meta), string::utf8(b"fruit"), Fruit{});
                let exp:&mut u64 = table::borrow_mut(&mut global.water_down_person_exp_records, sender);
                *exp = 0;
            } else {
                let exp:&mut u64 = table::borrow_mut(&mut global.water_down_person_exp_records, sender);
                *exp = *exp + 1;
            }
        } else {
            table::add(&mut global.water_down_person_exp_records, sender, 1);
        };
    }

    public entry fun swap_fragment(meta:&mut MetaIdentity) {
        let items = get_items(meta);
        let vec:vector<Fragment> = items::extract_items(items, string::utf8(b"fragment"), 10);
        let (i, len) = (0u64, vector::length(&vec));
        while (i < len) {
            let Fragment{} = vector::pop_back(&mut vec);
        };
        vector::destroy_empty(vec);
        items::store_item(items, string::utf8(b"water_element"), WaterElement{})
    }

    public entry fun open_fruit(meta:&mut MetaIdentity, ctx:&mut TxContext) {
        let Fruit {} = items::extract_item(get_items(meta), string::utf8(b"fruit"));
        let p = get_random_num(0, 1000, ctx);
        if (p < 10) {
            items::store_item(get_items(meta), string::utf8(b"water_element"), WaterElement{});
        } else {
            items::store_item(get_items(meta), string::utf8(b"fragment"), Fragment{});
        }
    }

    fun get_random_num(min:u64, max:u64, ctx:&mut TxContext) :u64 {
        (min + bytes_to_u64(seed(ctx))) % max
    }

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