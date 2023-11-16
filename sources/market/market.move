module shui_module::market {
    use std::ascii;
    use std::string::{Self, String, utf8};
    use std::vector;
    use sui::linked_table::{Self, LinkedTable};
    use sui::coin::{Self, Coin, value, destroy_zero};
    use sui::object::{UID, Self};
    use std::type_name::{Self, into_string};
    use sui::balance::{Self, Balance};
    use sui::sui::SUI;
    use std::debug::print;
    use sui::transfer;
    use sui::address;
    use sui::bag::{Self};
    use sui::tx_context::{Self, TxContext};
    use std::option::{Self};
    use sui::clock::{Self, Clock};
    use shui_module::metaIdentity::MetaIdentity;
    use shui_module::tree_of_life::Self;
    use shui_module::shui;

    const ERR_SALES_NOT_EXIST: u64 = 0x02;
    const ERR_NOT_OWNER: u64 = 0x03;
    const ERR_EXCEED_MAX_ON_SALE_NUM: u64 = 0x04;
    const ERR_INVALID_COIN:u64 = 0x05;

    struct MARKET has drop {}

    struct MarketGlobal has key {
        id: UID,
        balance_SHUI: Balance<shui::SHUI>,
        balance_SUI: Balance<SUI>,

        // wallet -> table<objid -> OnSaleInfo>
        game_sales : LinkedTable<address, vector<OnSale>>,
    }

    struct OnSale has key, store {
        id: UID,
        name: String,
        num: u64,
        price: u64,
        coinType: String,
        owner: address,
        type: String,
        onsale_time: u64,

        // at most store one obejct
        bag: bag::Bag
    }

    #[test_only]
    public fun init_for_test(ctx: &mut TxContext) {
        let global = MarketGlobal {
            id: object::new(ctx),
            balance_SHUI: balance::zero(),
            balance_SUI: balance::zero(),
            game_sales: linked_table::new<address, vector<OnSale>>(ctx),
        };
        transfer::share_object(global);
    }

    fun init(_witness: MARKET, ctx: &mut TxContext) {
        let global = MarketGlobal {
            id: object::new(ctx),
            balance_SHUI: balance::zero(),
            balance_SUI: balance::zero(),
            game_sales: linked_table::new<address, vector<OnSale>>(ctx),
        };
        transfer::share_object(global);
    }

    fun new_nft_sale<Nft:key + store>(name:String, price:u64, coinType:String, clock:&Clock, type:String, nft:Nft, ctx:&mut TxContext): OnSale {
        let now = clock::timestamp_ms(clock);
        let bags = bag::new(ctx);
        bag::add(&mut bags, 0, nft);
        OnSale {
            id: object::new(ctx),
            name: name,
            price: price,
            num: 1,
            coinType: coinType,
            owner:tx_context::sender(ctx),
            type: type,
            onsale_time: now,
            bag: bags
        }
    }

    fun new_sale(name:String, num:u64, price:u64, coinType:String, clock:&Clock, type:String, ctx:&mut TxContext): OnSale {
        let now = clock::timestamp_ms(clock);
        OnSale {
            id: object::new(ctx),
            name: name,
            price: price,
            coinType: coinType,
            num: num,
            owner:tx_context::sender(ctx),
            type: type,
            onsale_time: now,
            bag: bag::new(ctx)
        }
    }

    public fun get_game_sales_vec(global: &MarketGlobal) : &vector<OnSale> {
        let table = &global.game_sales;
        let key = linked_table::front(table);
        let key_value = *option::borrow(key);
        let sales = linked_table::borrow(table, key_value);
        sales
    }

    public entry fun get_game_sales(global: &MarketGlobal, _clock:&Clock) : string::String {
        let byte_semi = ascii::byte(ascii::char(59));
        let table = &global.game_sales;
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
        clock: &Clock, 
        ctx: &mut TxContext
    ) {
        assert!(owner == tx_context::sender(ctx), ERR_NOT_OWNER);
        assert!(linked_table::contains(&global.game_sales, owner), ERR_SALES_NOT_EXIST);
        let his_sales = linked_table::borrow_mut(&mut global.game_sales, owner);
        let (i, len) = (0u64, vector::length(his_sales));
        while (i < len) {
            let onSale:&OnSale = vector::borrow(his_sales, i);
            if (onSale.name == name && onSale.num == num && onSale.price == price) {
                let sale = vector::remove(his_sales, i);
                let OnSale {id, name:_, num:_, price:_, coinType:_, owner:_, type:_, onsale_time:_, bag:items} = sale;
                bag::destroy_empty(items);
                object::delete(id);
                if (vector::length(his_sales) == 0) {
                    let vec = linked_table::remove(&mut global.game_sales, owner);
                    vector::destroy_empty(vec);
                };
                tree_of_life::fill_items(meta, name, num);
                break
            };
            i = i + 1
        };
    }

    public entry fun unlist_nft_item<T:key+store> (
        global:&mut MarketGlobal, 
        meta: &mut MetaIdentity, 
        owner: address,
        name: String,
        num: u64,
        price: u64,
        clock: &Clock, 
        ctx: &mut TxContext
    ) {
        assert!(owner == tx_context::sender(ctx), ERR_NOT_OWNER);
        assert!(linked_table::contains(&global.game_sales, owner), ERR_SALES_NOT_EXIST);
        let his_sales = linked_table::borrow_mut(&mut global.game_sales, owner);
        let (i, len) = (0u64, vector::length(his_sales));
        while (i < len) {
            let onSale:&OnSale = vector::borrow(his_sales, i);
            if (onSale.name == name && onSale.num == num && onSale.price == price) {
                let sale = vector::remove(his_sales, i);
                let OnSale {id, name:_, num:_, price:_, coinType:_, owner:_, type:_, onsale_time:_, bag:items} = sale;
                if (bag::length(&items) > 0) {
                    let nft = bag::remove<u64, T>(&mut items, 0);
                    transfer::public_transfer(nft, tx_context::sender(ctx));
                };
                bag::destroy_empty(items);
                object::delete(id);
                if (vector::length(his_sales) == 0) {
                    let vec = linked_table::remove(&mut global.game_sales, owner);
                    vector::destroy_empty(vec);
                };
                break
            };
            i = i + 1
        };
    }

    public entry fun purchase_nft_item<T, Nft: key + store> (
        global:&mut MarketGlobal, 
        meta: &mut MetaIdentity, 
        owner: address,
        name: String,
        num: u64,
        payment:vector<Coin<T>>,
        _clock: &Clock, 
        ctx: &mut TxContext) {
        let merged_coins = merge_coins<T>(payment, ctx);
        assert!(linked_table::contains(&global.game_sales, owner), ERR_SALES_NOT_EXIST);
        let his_sales = linked_table::borrow_mut(&mut global.game_sales, owner);
        let (i, len) = (0u64, vector::length(his_sales));
        let value = value(&merged_coins);
        while (i < len) {
            let onSale:&OnSale = vector::borrow(his_sales, i);
            if (onSale.name == name && onSale.num == num && onSale.price <= value) {
                let sale = vector::remove(his_sales, i);
                let OnSale {id, name:_, num:_, price, coinType:coinType, owner:_, type:_, onsale_time:_, bag:items} = sale;
                let obj_type_name = type_name::get<T>();
                let obj_contract_str = string::utf8(ascii::into_bytes(into_string(obj_type_name)));
                if (coinType == utf8(b"SUI")) {
                    let shui_type = type_name::get<SUI>();
                    let shui_contract_str = string::utf8(ascii::into_bytes(into_string(shui_type)));
                    assert!(obj_contract_str == shui_contract_str, ERR_INVALID_COIN);
                } else if (coinType == utf8(b"SHUI")) {
                    let shui_type = type_name::get<shui::SHUI>();
                    let shui_contract_str = string::utf8(ascii::into_bytes(into_string(shui_type)));
                    assert!(obj_contract_str == shui_contract_str, ERR_INVALID_COIN);
                };
                if (bag::length(&items) > 0) {
                    let nft = bag::remove<u64, Nft>(&mut items, 0);
                    transfer::public_transfer(nft, tx_context::sender(ctx));
                };
                bag::destroy_empty(items);
                object::delete(id);
                if (vector::length(his_sales) == 0) {
                    let vec = linked_table::remove(&mut global.game_sales, owner);
                    vector::destroy_empty(vec);
                };
                let payment = coin::split<T>(&mut merged_coins, price, ctx);
                transfer::public_transfer(payment, owner);
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

    public entry fun purchase_game_item<T> (
        global:&mut MarketGlobal, 
        meta: &mut MetaIdentity, 
        owner: address,
        name: String,
        num: u64,
        payment:vector<Coin<T>>,
        _clock: &Clock, 
        ctx: &mut TxContext) {
        let merged_coins = merge_coins<T>(payment, ctx);
        assert!(linked_table::contains(&global.game_sales, owner), ERR_SALES_NOT_EXIST);
        let his_sales = linked_table::borrow_mut(&mut global.game_sales, owner);
        let (i, len) = (0u64, vector::length(his_sales));
        let value = value(&merged_coins);
        while (i < len) {
            let onSale:&OnSale = vector::borrow(his_sales, i);
            if (onSale.name == name && onSale.num == num && onSale.price <= value) {
                let sale = vector::remove(his_sales, i);
                let OnSale {id, name:_, num:_, price, coinType:coinType, owner:_, type:_, onsale_time:_, bag:items} = sale;
                let obj_type_name = type_name::get<T>();
                let obj_contract_str = string::utf8(ascii::into_bytes(into_string(obj_type_name)));
                if (coinType == utf8(b"SUI")) {
                    let shui_type = type_name::get<SUI>();
                    let shui_contract_str = string::utf8(ascii::into_bytes(into_string(shui_type)));
                    assert!(obj_contract_str == shui_contract_str, ERR_INVALID_COIN);
                } else if (coinType == utf8(b"SHUI")) {
                    let shui_type = type_name::get<shui::SHUI>();
                    let shui_contract_str = string::utf8(ascii::into_bytes(into_string(shui_type)));
                    assert!(obj_contract_str == shui_contract_str, ERR_INVALID_COIN);
                };
                bag::destroy_empty(items);
                object::delete(id);
                if (vector::length(his_sales) == 0) {
                    let vec = linked_table::remove(&mut global.game_sales, owner);
                    vector::destroy_empty(vec);
                };
                let payment = coin::split<T>(&mut merged_coins, price, ctx);
                transfer::public_transfer(payment, owner);
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

    public fun merge_coins<T>(
        coins: vector<Coin<T>>,
        ctx: &mut TxContext,
    ): Coin<T> {
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
            coin::zero<T>(ctx)
        }
    }

    public entry fun list_game_item (
        global: &mut MarketGlobal,
        meta: &mut MetaIdentity,
        name: String,
        price: u64,
        num: u64,
        coinType: String,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        tree_of_life::extract_drop_items(meta, name, num);
        let sales = &mut global.game_sales;
        let owner = tx_context::sender(ctx);
        let type = utf8(b"gamefi");
        assert!((coinType == utf8(b"SUI") || coinType == utf8(b"SHUI")), ERR_INVALID_COIN);
        if (linked_table::contains(sales, owner)) {
            let my_sales = linked_table::borrow_mut(sales, owner);
            assert!(vector::length(my_sales) <= 10, ERR_EXCEED_MAX_ON_SALE_NUM);
            let new_sale = new_sale(name, num, price, coinType, clock, type, ctx);
            vector::push_back(my_sales, new_sale);
        } else {
            let new_sales = vector::empty<OnSale>();
            let new_sale = new_sale(name, num, price, coinType, clock, type, ctx);
            vector::push_back(&mut new_sales, new_sale);
            linked_table::push_back(sales, owner, new_sales);
        };
    }

    public entry fun list_nft_item<Nft:key + store> (
        global: &mut MarketGlobal,
        meta: &mut MetaIdentity,
        name: String,
        price: u64,
        coinType: String,
        clock: &Clock,
        nft:Nft,
        ctx: &mut TxContext
    ) {
        let sales = &mut global.game_sales;
        let owner = tx_context::sender(ctx);
        let type = utf8(b"nft");
        assert!((coinType == utf8(b"SUI") || coinType == utf8(b"SHUI")), ERR_INVALID_COIN);
        if (linked_table::contains(sales, owner)) {
            let my_sales = linked_table::borrow_mut(sales, owner);
            assert!(vector::length(my_sales) <= 10, ERR_EXCEED_MAX_ON_SALE_NUM);
            let new_sale = new_nft_sale<Nft>(name, price, coinType, clock, type, nft, ctx);
            vector::push_back(my_sales, new_sale);
        } else {
            let new_sales = vector::empty<OnSale>();
            let new_sale = new_nft_sale<Nft>(name, price, coinType, clock, type, nft, ctx);
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