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
    use shui_module::metaIdentity::{Self, MetaIdentity, get_items};
    use std::string;
    use sui::event;

    const DAY_IN_MS: u64 = 86_400_000;
    const ERR_INTERVAL_TIME_ONE_DAY:u64 = 0x001;
    const ERR_WRONG_COMBINE_NUM:u64 = 0x002;
    const ERR_WRONG_TYPE:u64 = 0x003;
    const ERR_COIN_NOT_ENOUGH:u64 = 0x004;

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

    // ====== Events ======
    // For when someone has purchased a donut.
    struct FruitOpened has copy, drop {
        meta_id: u64,
        name: string::String,
        reward: string::String
    }

    struct WaterDownEvent has copy, drop {
        meta_id: u64,
        name: string::String,
    }

    struct WaterElementHoly has store, drop {}
    struct WaterElementMemory has store, drop {}
    struct WaterElementBlood has store, drop {}
    struct WaterElementResurrect has store, drop {}
    struct WaterElementLife has store, drop {}

    struct FragmentHoly has store, drop {}
    struct FragmentMemory has store, drop {}
    struct FragmentBlood  has store, drop {}
    struct FragmentResurrect has store, drop {}
    struct FragmentLife has store, drop {}

    struct Fruit has store {}

    fun init(ctx: &mut TxContext) {
        let global = TreeGlobal {
            id: object::new(ctx),
            balance_SHUI: balance::zero(),
            creator: tx_context::sender(ctx),
            water_down_last_time_records: table::new<address, u64>(ctx),
            water_down_person_exp_records: table::new<address, u64>(ctx),
        };
        transfer::share_object(global);
    }

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
            let lastWaterDownTime = table::borrow_mut(&mut global.water_down_last_time_records, sender);

            // for test 86_400_000 <- 60_000
            assert!((now - *lastWaterDownTime) > 60_000, ERR_INTERVAL_TIME_ONE_DAY);
            *lastWaterDownTime = now;
        } else {
            table::add(&mut global.water_down_last_time_records, sender, now);
        };
        let merged_coin = vector::pop_back(&mut coins);
        pay::join_vec(&mut merged_coin, coins);
        assert!(coin::value(&merged_coin) >= amount * 1_000_000, ERR_COIN_NOT_ENOUGH);
        let balance = coin::into_balance<SHUI>(
            coin::split<SHUI>(&mut merged_coin, amount * 1_000_000, ctx)
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
            if (last_exp == 2) {
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

        event::emit(
            WaterDownEvent {
                meta_id: metaIdentity::getMetaId(meta),
                name: metaIdentity::get_meta_name(meta),
            }
        )
    }

    public entry fun swap_fragment<T:store + drop>(meta:&mut MetaIdentity, fragment_type:string::String) {
        let items = get_items(meta);
        let vec:vector<T> = items::extract_items(items, fragment_type, 10);
        let (i, len) = (0u64, vector::length(&vec));
        while (i < len) {
            // drop fragments
            vector::pop_back(&mut vec);
        };
        vector::destroy_empty(vec);
        if (fragment_type == string::utf8(b"water_element_holy")) {
            items::store_item(get_items(meta), fragment_type, WaterElementHoly{});
        } else if (fragment_type == string::utf8(b"water_element_memory")) {
            items::store_item(get_items(meta), fragment_type, WaterElementMemory{});
        } else if (fragment_type == string::utf8(b"water_element_blood")) {
            items::store_item(get_items(meta), fragment_type, WaterElementBlood{});
        } else if (fragment_type == string::utf8(b"fragment_holy")) {
            items::store_item(get_items(meta), fragment_type, FragmentHoly{});
        } else if (fragment_type == string::utf8(b"water_element_resurrect")) {
            items::store_item(get_items(meta), fragment_type, WaterElementResurrect{});
        } else if (fragment_type == string::utf8(b"fragment_memory")) {
            items::store_item(get_items(meta), fragment_type, FragmentMemory{});
        } else if (fragment_type == string::utf8(b"water_element_life")) {
            items::store_item(get_items(meta), fragment_type, WaterElementLife{});
        } else if (fragment_type == string::utf8(b"fragment_blood")) {
            items::store_item(get_items(meta), fragment_type, FragmentBlood{});
        } else if (fragment_type == string::utf8(b"fragment_resurrect")) {
            items::store_item(get_items(meta), fragment_type, FragmentResurrect{});
        } else if (fragment_type == string::utf8(b"fragment_life")) {
            items::store_item(get_items(meta), fragment_type, FragmentLife{});
        }
    }

    public entry fun open_fruit(meta:&mut MetaIdentity, ctx:&mut TxContext) {
        let Fruit {} = items::extract_item(get_items(meta), string::utf8(b"fruit"));
        let num = get_random_num(0, 30611, ctx);
        let reword_string;
        if (num <= 1) {
            reword_string = string::utf8(b"fragment_life");
            items::store_item(get_items(meta), string::utf8(b"water_element_holy"), WaterElementHoly{});
        } else if (num <= 11) {
            reword_string = string::utf8(b"water_element_memory");
            items::store_item(get_items(meta), reword_string, WaterElementMemory{});
        } else if (num <= 111) {
            reword_string = string::utf8(b"water_element_blood");
            items::store_item(get_items(meta), reword_string, WaterElementBlood{});
        } else if (num <= 611) {
            reword_string = string::utf8(b"fragment_holy");
            items::store_item(get_items(meta), reword_string, FragmentHoly{});
        } else if (num <= 1611) {
            reword_string = string::utf8(b"water_element_resurrect");
            items::store_item(get_items(meta), reword_string, WaterElementResurrect{});
        } else if (num <= 4111) {
            reword_string = string::utf8(b"fragment_memory");
            items::store_item(get_items(meta), reword_string, FragmentMemory{});
        } else if (num <= 9111) {
            reword_string = string::utf8(b"water_element_life");
            items::store_item(get_items(meta), reword_string, WaterElementLife{});
        } else if (num <= 14611) {
            reword_string = string::utf8(b"fragment_blood");
            items::store_item(get_items(meta), reword_string, FragmentBlood{});
        } else if (num <= 21611) {
            reword_string = string::utf8(b"fragment_resurrect");
            items::store_item(get_items(meta), reword_string, FragmentResurrect{});
        } else {
            reword_string = string::utf8(b"fragment_life");
            items::store_item(get_items(meta), reword_string, FragmentLife{});
        };
        event::emit(
            FruitOpened {
                meta_id: metaIdentity::get_meta_id(meta),
                name: metaIdentity::get_meta_name(meta),
                reward: reword_string
            }
        );
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

    public fun get_water_down_person_exp(global: &TreeGlobal, wallet_addr:address):u64 {
        *table::borrow(&global.water_down_person_exp_records, wallet_addr)
    }
}