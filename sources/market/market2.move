module shui_module::market2 {
    use std::ascii;
    use std::string::{Self, String, utf8};
    use std::vector;
    use sui::linked_table::{Self, LinkedTable};
    use sui::coin::{Self, Coin, value, destroy_zero};
    use sui::object::{UID, Self};
    use sui::balance::{Self, Balance};
    use sui::sui::SUI;
    use std::debug::print;
    use sui::transfer;
    use sui::address;
    use sui::tx_context::{Self, TxContext};
    use std::option::{Self};
    use sui::clock::{Self, Clock};
    use shui_module::metaIdentity::MetaIdentity;
    use shui_module::tree_of_life::Self;
    use shui_module::shui;

    const ERR_SALES_NOT_EXIST: u64 = 0x02;
    const ERR_NOT_OWNER: u64 = 0x03;
    const ERR_EXCEED_MAX_ON_SALE_NUM: u64 = 0x04;

    struct MARKET2 has drop {}

    struct MarketGlobal has key {
        id: UID,
        balance_SHUI: Balance<shui::SHUI>,
        balance_SUI: Balance<SUI>,

        // wallet -> table<objid -> OnSaleInfo>
        market_sales : LinkedTable<address, vector<OnSale>>
    }

    struct OnSale has key, store {
        id: UID,
        name: String,
        num: u64,
        price: u64,
        owner: address,
        type: String,
        onsale_time: u64
    }

    #[test_only]
    public fun init_for_test(ctx: &mut TxContext) {
        let global = MarketGlobal {
            id: object::new(ctx),
            balance_SHUI: balance::zero(),
            balance_SUI: balance::zero(),
            market_sales: linked_table::new<address, vector<OnSale>>(ctx),
        };
        transfer::share_object(global);
    }

    fun init(_witness: MARKET2, ctx: &mut TxContext) {
        let global = MarketGlobal {
            id: object::new(ctx),
            balance_SHUI: balance::zero(),
            balance_SUI: balance::zero(),
            market_sales: linked_table::new<address, vector<OnSale>>(ctx),
        };
        transfer::share_object(global);
    }

    fun new_sale(name:String, num:u64, price:u64, clock:&Clock, type:String, ctx:&mut TxContext): OnSale {
        let now = clock::timestamp_ms(clock);
        OnSale {
            id: object::new(ctx),
            name: name,
            price: price,
            num: num,
            owner:tx_context::sender(ctx),
            type: type,
            onsale_time: now
        }
    }

    public fun get_market_sales2(global: &MarketGlobal) : &vector<OnSale> {
        // let vec_out = vector::empty<OnSale>();
        let table = &global.market_sales;

        let key = linked_table::front(table);
        let key_value = *option::borrow(key);
        let sales = linked_table::borrow(table, key_value);
        sales
        // loop the vector

        // let next = linked_table::next(table, *option::borrow(key));
        // while (option::is_some(next)) {
        //     let key_value = *option::borrow(next);
        //     vector::append(&mut vec_out, *string::bytes(&key_value));
        //     vector::push_back(&mut vec_out, byte_colon);

        //     let val_str = linked_table::borrow(table, key_value);
        //     vector::append(&mut vec_out, numbers_to_ascii_vector(*val_str));
        //     vector::push_back(&mut vec_out, byte_comma);
        //     vector::push_back(&mut vec_out, byte_semi);
        //     next = linked_table::next(table, key_value);
        // };
        // &vec_out
    }

    public entry fun get_market_sales(global: &MarketGlobal, _clock:&Clock) : string::String {
        // ;
        let byte_semi = ascii::byte(ascii::char(59));
        let table = &global.market_sales;
        if (linked_table::is_empty(table)) {
            return utf8(b"none")
        };
        let vec_out:vector<u8> = *string::bytes(&string::utf8(b""));
        let key = linked_table::front(table);
        let key_value = *option::borrow(key);
        let sales_vec = linked_table::borrow(table, key_value);
        vector::append(&mut vec_out, print_onsale_vector(sales_vec));
        let next = linked_table::next(table, *option::borrow(key));
        while (option::is_some(next)) {
            key_value = *option::borrow(next);
            sales_vec = linked_table::borrow(table, key_value);
            vector::append(&mut vec_out, print_onsale_vector(sales_vec));
            next = linked_table::next(table, key_value);
        };
        utf8(vec_out)
    }

    fun print_onsale_vector(my_sales:&vector<OnSale>): vector<u8> {
        // ;
        let byte_semi = ascii::byte(ascii::char(59));
        // ,
        let byte_comma = ascii::byte(ascii::char(44));
        let vec_out:vector<u8> = *string::bytes(&string::utf8(b""));
        let (i, len) = (0u64, vector::length(my_sales));
        while (i < len) {
            let onSale:&OnSale = vector::borrow(my_sales, i);
            let onsale_id_str = address::to_string(object::uid_to_address(&onSale.id));
            vector::append(&mut vec_out, *string::bytes(&string::utf8(b"0x")));
            vector::append(&mut vec_out, *string::bytes(&onsale_id_str));
            vector::push_back(&mut vec_out, byte_comma);
            vector::append(&mut vec_out, *string::bytes(&onSale.name));
            vector::push_back(&mut vec_out, byte_comma);
            vector::append(&mut vec_out, numbers_to_ascii_vector(onSale.num));
            vector::push_back(&mut vec_out, byte_comma);
            vector::append(&mut vec_out, numbers_to_ascii_vector(onSale.price));
            vector::push_back(&mut vec_out, byte_comma);
            vector::append(&mut vec_out, *string::bytes(&onSale.type));
            vector::push_back(&mut vec_out, byte_comma);
            let owner_addr_str = address::to_string(onSale.owner);
            vector::append(&mut vec_out, *string::bytes(&string::utf8(b"0x")));
            vector::append(&mut vec_out, *string::bytes(&owner_addr_str));
            vector::push_back(&mut vec_out, byte_comma);
            vector::append(&mut vec_out, numbers_to_ascii_vector(onSale.onsale_time));
            vector::push_back(&mut vec_out, byte_semi);
            i = i + 1
        };
        vec_out
    }

    public entry fun unlist_game_item (
        global:&mut MarketGlobal, 
        meta: &mut MetaIdentity, 
        owner: address,
        name: String,
        num: u64,
        price: u64,
        _clock: &Clock, 
        ctx: &mut TxContext
    ) {
        // todo:anyone can unlist item out of deadline
        assert!(owner == tx_context::sender(ctx), ERR_NOT_OWNER);
        assert!(linked_table::contains(&global.market_sales, owner), ERR_SALES_NOT_EXIST);
        let his_sales = linked_table::borrow_mut(&mut global.market_sales, owner);
        let (i, len) = (0u64, vector::length(his_sales));
        while (i < len) {
            let onSale:&OnSale = vector::borrow(his_sales, i);
            if (onSale.name == name && onSale.num == num && onSale.price == price) {
                let sale = vector::remove(his_sales, i);
                let OnSale {id, name:_, num:_, price:_, owner:_, type:_, onsale_time:_} = sale;
                object::delete(id);
                if (vector::length(his_sales) == 0) {
                    let vec = linked_table::remove(&mut global.market_sales, owner);
                    vector::destroy_empty(vec);
                };
                tree_of_life::fill_items(meta, name, num);
                break
            };
            i = i + 1
        };
    }

    public entry fun purchase_game_item (
        global:&mut MarketGlobal, 
        meta: &mut MetaIdentity, 
        owner: address,
        name: String,
        num: u64,
        payment:vector<Coin<SUI>>,
        _clock: &Clock, 
        ctx: &mut TxContext) {
        let merged_coins = merge_coins(payment, ctx);
        assert!(linked_table::contains(&global.market_sales, owner), ERR_SALES_NOT_EXIST);
        let his_sales = linked_table::borrow_mut(&mut global.market_sales, owner);
        let (i, len) = (0u64, vector::length(his_sales));
        let value = value(&merged_coins);
        while (i < len) {
            let onSale:&OnSale = vector::borrow(his_sales, i);
            if (onSale.name == name && onSale.num == num && onSale.price <= value) {
                let sale = vector::remove(his_sales, i);
                let OnSale {id, name:_, num:_, price, owner:_, type:_, onsale_time:_} = sale;
                object::delete(id);
                if (vector::length(his_sales) == 0) {
                    let vec = linked_table::remove(&mut global.market_sales, owner);
                    vector::destroy_empty(vec);
                };
                let balance = coin::into_balance<SUI>(
                    coin::split<SUI>(&mut merged_coins, price, ctx)
                );
                balance::join(&mut global.balance_SUI, balance);
                tree_of_life::fill_items(meta, name, num);
                break
            };
            i = i + 1
        };
        value = value(&merged_coins);
        if (value > 0) {
            transfer::public_transfer(merged_coins, tx_context::sender(ctx))
        } else {
            destroy_zero(merged_coins);
        };
    }


    public fun merge_coins(
        coins: vector<Coin<SUI>>,
        ctx: &mut TxContext,
    ): Coin<SUI> {
        let len = vector::length(&coins);
        if (len > 0) {
            let base_coin = vector::pop_back(&mut coins);
            while (!vector::is_empty(&coins)) {
                coin::join(&mut base_coin, vector::pop_back(&mut coins));
            };
            vector::destroy_empty(coins);

            base_coin
        } else {
            vector::destroy_empty(coins);
            coin::zero<SUI>(ctx)
        }
    }

    public entry fun list_game_item (
        global: &mut MarketGlobal,
        meta: &mut MetaIdentity,
        name: String,
        num: u64,
        price: u64,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        tree_of_life::extract_drop_items(meta, name, num);
        let sales = &mut global.market_sales;
        let owner = tx_context::sender(ctx);
        let type = utf8(b"gamefi");
        if (linked_table::contains(sales, owner)) {
            let my_sales = linked_table::borrow_mut(sales, owner);
            assert!(vector::length(my_sales) <= 10, ERR_EXCEED_MAX_ON_SALE_NUM);
            let new_sale = new_sale(name, num, price, clock, type, ctx);
            vector::push_back(my_sales, new_sale);
        } else {
            let new_sales = vector::empty<OnSale>();
            let new_sale = new_sale(name, num, price, clock, type, ctx);
            vector::push_back(&mut new_sales, new_sale);
            linked_table::push_back(sales, owner, new_sales);
        };
    }

    fun numbers_to_ascii_vector(val: u64): vector<u8> {
        let vec = vector<u8>[];
        loop {
            let b = val % 10;
            vector::push_back(&mut vec, (48 + b as u8));
            val = val / 10;
            if (val <= 0) break;
        };
        vector::reverse(&mut vec);
        vec
    }
}