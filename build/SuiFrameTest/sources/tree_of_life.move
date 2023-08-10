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
    use shui_module::shui_ticket::{Self};
    use std::string;
    use sui::event;

    const DAY_IN_MS: u64 = 86_400_000;
    const HOUR_IN_MS: u64 = 3_600_000;
    const AMOUNT_DECIMAL: u64 = 1_000_000_000;
    const ERR_INTERVAL_TIME_ONE_DAY:u64 = 0x001;
    const ERR_WRONG_COMBINE_NUM:u64 = 0x002;
    const ERR_WRONG_TYPE:u64 = 0x003;
    const ERR_COIN_NOT_ENOUGH:u64 = 0x004;
    const ERR_INVALID_NAME:u64 = 0x005;
    const ERR_INVALID_TYPE:u64 = 0x006;

    struct Tree_of_life has key, store {
        id:UID,
        level:u16,
        exp:u16,
    }

    struct TreeGlobal has key {
        id: UID,
        balance_SHUI: Balance<SHUI>,
        creator: address,
        water_down_last_time_records: Table<u64, u64>,
        water_down_person_exp_records: Table<u64, u64>,
    }

    // ====== Events ======
    // For when someone has purchased a donut.
    struct FruitOpened has copy, drop {
        meta_id: u64,
        name: string::String,
        element_reward: string::String,
        ticket_reward: string::String,
    }

    struct TicketOpen has copy, drop {
        meta_id: u64,
        amount: u64
    }

    struct WaterElement has store, drop {
        class:string::String
    }

    struct Fragment has store, drop {
        class:string::String
    }

    struct Fruit has store {}


    #[test_only]
    public fun init_for_test(ctx: &mut TxContext) {
        let global = TreeGlobal {
            id: object::new(ctx),
            balance_SHUI: balance::zero(),
            creator: tx_context::sender(ctx),
            water_down_last_time_records: table::new<address, u64>(ctx),
            water_down_person_exp_records: table::new<address, u64>(ctx),
        };
        transfer::share_object(global);
    }

    fun init(ctx: &mut TxContext) {
        let global = TreeGlobal {
            id: object::new(ctx),
            balance_SHUI: balance::zero(),
            creator: tx_context::sender(ctx),
            water_down_last_time_records: table::new<u64, u64>(ctx),
            water_down_person_exp_records: table::new<ur64, u64>(ctx),
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

    public entry fun water_down(global: &mut TreeGlobal, meta:&MetaIdentity, coins:vector<Coin<SHUI>>, clock: &Clock, ctx:&mut TxContext) {
        // interval time should be greater than 1 days
        let amount = 1;
        let sender = tx_context::sender(ctx);
        let now = clock::timestamp_ms(clock);
        if (table::contains(&global.water_down_last_time_records, metaIdentity::get_meta_id(meta))) {
            let lastWaterDownTime = table::borrow_mut(&mut global.water_down_last_time_records, metaIdentity::get_meta_id(meta));
            assert!((now - *lastWaterDownTime) > 8 * HOUR_IN_MS, ERR_INTERVAL_TIME_ONE_DAY);
            *lastWaterDownTime = now;
        } else {
            table::add(&mut global.water_down_last_time_records, metaIdentity::get_meta_id(meta), now);
        };
        let merged_coin = vector::pop_back(&mut coins);
        pay::join_vec(&mut merged_coin, coins);
        assert!(coin::value(&merged_coin) >= amount * AMOUNT_DECIMAL, ERR_COIN_NOT_ENOUGH);
        let balance = coin::into_balance<SHUI>(
            coin::split<SHUI>(&mut merged_coin, amount * AMOUNT_DECIMAL, ctx)
        );
        balance::join(&mut global.balance_SHUI, balance);
        if (coin::value(&merged_coin) > 0) {
            transfer::public_transfer(merged_coin, tx_context::sender(ctx))
        } else {
            destroy_zero(merged_coin)
        };

        // record the time and exp
        if (table::contains(&global.water_down_person_exp_records, metaIdentity::get_meta_id(meta))) {
            let last_exp = *table::borrow(&global.water_down_person_exp_records, metaIdentity::get_meta_id(meta));
            if (last_exp == 9) {
                items::store_item(get_items(meta), string::utf8(b"fruit"), Fruit{});
                let exp:&mut u64 = table::borrow_mut(&mut global.water_down_person_exp_records, metaIdentity::get_meta_id(meta));
                *exp = 0;
            } else {
                let exp:&mut u64 = table::borrow_mut(&mut global.water_down_person_exp_records, metaIdentity::get_meta_id(meta));
                *exp = *exp + 1;
            }
        } else {
            table::add(&mut global.water_down_person_exp_records, metaIdentity::get_meta_id(meta), 1);
        };
    }

    public entry fun swap_fragment<T:store + drop>(meta:&mut MetaIdentity, fragment_type:string::String) {
        assert!(check_class(&fragment_type), ERR_INVALID_TYPE);
        let items = get_items(meta);
        let fragment_name = string::utf8(b"fragment_");
        string::append(&mut fragment_name, fragment_type);
        let vec:vector<T> = items::extract_items(items, fragment_name, 10);
        let (i, len) = (0u64, vector::length(&vec));
        while (i < len) {
            // drop fragments
            vector::pop_back(&mut vec);
            i = i + 1;
        };
        vector::destroy_empty(vec);
        let water_element_name = string::utf8(b"water_element_");
        string::append(&mut water_element_name, *&fragment_type);
        items::store_item(get_items(meta), water_element_name, WaterElement {
            class:fragment_type
        });
    }

    fun check_class(class: &string::String) : bool {
        let array = vector::empty<string::String>();
        vector::push_back(&mut array, string::utf8(b"life"));
        vector::push_back(&mut array, string::utf8(b"holy"));
        vector::push_back(&mut array, string::utf8(b"memory"));
        vector::push_back(&mut array, string::utf8(b"resurrect"));
        vector::push_back(&mut array, string::utf8(b"blood"));
        vector::contains(&array, class)
    }

    fun random_ticket(ctx:&mut TxContext): string::String {
        let num = get_random_num(0, 10000, 0, ctx);
        let reward_string;
        if (num == 0) {
            reward_string = string::utf8(b"shui_5000");
            shui_ticket::mint(5000, ctx)
        } else if (num <= 49) {
            reward_string = string::utf8(b"shui_1000");
            shui_ticket::mint(1000, ctx)
        } else if (num <= 250) {
            reward_string = string::utf8(b"shui_100");
            shui_ticket::mint(100, ctx)
        } else if (num <= 1700) {
            reward_string = string::utf8(b"shui_10");
            shui_ticket::mint(10, ctx)
        } else {
            reward_string = string::utf8(b"");
        };
        reward_string
    }

    fun create_fragments_by_class(loop_num:u64, type:string::String) : vector<Fragment> {
        assert!(check_class(&type), ERR_INVALID_TYPE);
        let array = vector::empty();
        let i = 0;
        while (i < loop_num) {
            vector::push_back(&mut array, Fragment{
                class:type
            });
            i = i + 1;
        };
        array
    }

    fun receive_random_element(random:u64, meta:&mut MetaIdentity):string::String {
        let reward_string;
        let is_fragment = true;
        if (random == 0) {
            reward_string = string::utf8(b"life");
            is_fragment = false;
        } else if (random <= 11) {
            reward_string = string::utf8(b"memory");
            is_fragment = false;
        } else if (random <= 111) {
            reward_string = string::utf8(b"blood");
            is_fragment = false;
        } else if (random <= 611) {
            reward_string = string::utf8(b"holy");
        } else if (random <= 1611) {
            reward_string = string::utf8(b"resurrect");
            is_fragment = false;
        } else if (random <= 4111) {
            reward_string = string::utf8(b"memory");
            is_fragment = false;
        } else if (random <= 9111) {
            reward_string = string::utf8(b"life");
        } else if (random <= 14611) {
            reward_string = string::utf8(b"blood");
        } else if (random <= 21611) {
            reward_string = string::utf8(b"resurrect");
        } else {
            reward_string = string::utf8(b"holy");
        };
        if (is_fragment) {
            let name = string::utf8(b"fragment_");
            string::append(&mut name, *&reward_string);
            let array = create_fragments_by_class(5, *&reward_string);
            items::store_items(get_items(meta), name, array);
            name
        } else {
            let name = string::utf8(b"water_element_");
            string::append(&mut name, *&reward_string);
            items::store_item(get_items(meta), name, WaterElement{
                class:reward_string
            });
            name
        }
    }

    public entry fun open_fruit(meta:&mut MetaIdentity, ctx:&mut TxContext) {
        let Fruit {} = items::extract_item(get_items(meta), string::utf8(b"fruit"));
        let num = get_random_num(0, 30610, 0, ctx);
        let num_u8 = num % 255;
        let reword_element : string::String = receive_random_element(num, meta);
        let double_chance = get_random_num(0, 10, (num_u8 as u8), ctx);
        if (double_chance < 5) {
            let reward_element2 = receive_random_element(double_chance, meta);
            string::append(&mut reword_element, string::utf8(b";"));
            string::append(&mut reword_element, reward_element2);
        };
        let reword_ticket : string::String = random_ticket(ctx);
        event::emit(
            FruitOpened {
                meta_id: metaIdentity::get_meta_id(meta),
                name: metaIdentity::get_meta_name(meta),
                element_reward: reword_element,
                ticket_reward: reword_ticket
            }
        );
    }

    // [min, max]
    public fun get_random_num(min:u64, max:u64, seed_u:u8, ctx:&mut TxContext) :u64 {
        (min + bytes_to_u64(seed(ctx, seed_u))) % (max + 1)
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

    fun seed(ctx: &mut TxContext, seed_u:u8): vector<u8> {
        let ctx_bytes = bcs::to_bytes(ctx);
        let seed_vec = vector::empty();
        vector::push_back(&mut seed_vec, seed_u);
        let uid = object::new(ctx);
        let uid_bytes: vector<u8> = object::uid_to_bytes(&uid);
        object::delete(uid);
        let info: vector<u8> = vector::empty<u8>();
        vector::append<u8>(&mut info, ctx_bytes);

        vector::append<u8>(&mut info, seed_vec);

        vector::append<u8>(&mut info, uid_bytes);
        vector::append<u8>(&mut info, bcs::to_bytes(&tx_context::epoch_timestamp_ms(ctx)));
        let hash: vector<u8> = hash::keccak256(&info);
        hash
    }

    public fun get_water_down_person_exp(global: &TreeGlobal, meta_id: address) :u64 {
        if (table::contains(&global.water_down_person_exp_records, meta_id)) {
            *table::borrow(&global.water_down_person_exp_records, meta_id)
        } else {
            0
        }
    }

    public fun get_water_down_left_time_mills(global: &TreeGlobal, meta:&MetaIdentity, clock: &Clock) : u64 {
        let now = clock::timestamp_ms(clock);
        let last_time = 0;
        if (table::contains(&global.water_down_last_time_records, metaIdentity::get_meta_id(meta))) {
            last_time = *table::borrow(&global.water_down_last_time_records, metaIdentity::get_meta_id(meta));
        };
        let next_time = last_time + 8 * HOUR_IN_MS;
        if (now > next_time) {
            now - next_time
        } else {
            0
        }
    }
}