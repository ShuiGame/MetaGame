module shui_module::market2 {
    use std::ascii;
    use std::string::{Self, String, utf8};
    use std::type_name::{Self, into_string};
    use std::vector;

    use sui::coin::{Self, Coin, value};
    use sui::event;
    use sui::kiosk::{Self, KioskOwnerCap, Kiosk};
    use sui::object::Self;
    use sui::pay;
    use sui::sui::SUI;
    use sui::transfer;
    use sui::transfer_policy::{Self as policy, TransferPolicy};
    use sui::tx_context::{Self, TxContext, sender};
    use sui::dynamic_field;
    use shui_module::comparator::{compare, is_equal};
    use shui_module::metaIdentity::MetaIdentity;
    use shui_module::tree_of_life::Self;

    const ERR_INSUFFICIENT_ROYALTY_COIN: u64 = 0x01;
    const ERR_SALES_NOT_EXIST: u64 = 0x02;
    const ERR_NOT_OWNER: u64 = 0X03;
    const ERR_EXCEED_MAX_ON_SALE_NUM: u64 = 0x04;

    struct MARKET2 has drop {}

    struct MarketGlobal has key {
        id: UID,
        balance_SHUI: Balance<shui::SHUI>,
        balance_SUI: Balance<sui::SUI>,

        // wallet -> table<objid -> OnSaleInfo>
        market_sales = LinkedTable<address, vector<OnSale>>
    }

    struct OnSale has store, copy {
        id: UID,
        name: String,
        num: u8,
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
            balance_SUI: balance::zero,
            market_sales: linked_table::new<address, vector<OnSale>>(ctx),
        };
        transfer::share_object(global);
    }

    fun init(ctx: &mut TxContext) {
        let global = MarketGlobal {
            id: object::new(ctx),
            balance_SHUI: balance::zero(),
            balance_SUI: balance::zero,
            market_sales: linked_table::new<address, vector<OnSale>>(ctx),
        };
        transfer::share_object(global);
    }

    fun new_sale(name:String, num:u8, price:u64, clock:&Clock, type:String, ctx:&mut TxContext): OnSale {
        let now = clock::timestamp_ms(clock);
        OnSale {
            id: object::new(ctx),
            name: name,
            price: price,
            num: num,
            type: type,
            onsale_time: now
        }
    }

    public entry get_market_sales2(global: &MarketGlobal) : &vector<OnSale> {
        let vec_out = vector::new<OnSale>;
        let table = &global.market_sales;
        if (linked_table::is_empty(table)) {
            return string::utf8(b"none")
        };
        let key:address = linked_table::front(table);
        let key_value = *option::borrow(key);
        let sales = linked_table::borrow(table, key_value);
        // loop the vector
        

        let next = linked_table::next(table, *option::borrow(key));
        while (option::is_some(next)) {
            let key_value = *option::borrow(next);
            vector::append(&mut vec_out, *string::bytes(&key_value));
            vector::push_back(&mut vec_out, byte_colon);

            let val_str = linked_table::borrow(table, key_value);
            vector::append(&mut vec_out, numbers_to_ascii_vector(*val_str));
            vector::push_back(&mut vec_out, byte_comma);
            let desc_str = get_desc_by_name(itemGlobal, key_value);
            vector::append(&mut vec_out, *string::bytes(&desc_str));
            vector::push_back(&mut vec_out, byte_semi);
            next = linked_table::next(table, key_value);
        };
        &vec_out
    }

    public entry get_market_sales(global: &MarketGlobal, clock:&Clock) : String {
        // ;
        let byte_semi = ascii::byte(ascii::char(59));
        let table = &global.market_sales;
        if (linked_table::is_empty(table)) {
            return string::utf8(b"none")
        };
        let vec_out:vector<u8> = *string::bytes(&string::utf8(b""));
        let key:address = linked_table::front(table);
        let key_value = *option::borrow(key);
        let sales_vec = link_table::borrow(table, &key_value);
        vector::push_back(&mut vec_out, print_onsale_vector(sales_vec));
        let next = linked_table::next(table, *option::borrow(key));
        vector::push_back(&mut vec_out, byte_semi);
        while (option::is_some(next)) {
            key_value = *option::borrow(next);
            ales_vec = link_table::borrow(table, &key_value);
            vector::push_back(&mut vec_out, print_onsale_vector(sales_vec));
            vector::push_back(&mut vec_out, byte_semi);
        };
        vec_out
    }

    fun print_onsale_vector(my_sales:&vector<OnSale>): bytes {
        // ;
        let byte_semi = ascii::byte(ascii::char(59));
        // ,
        let byte_comma = ascii::byte(ascii::char(44));
        let vec_out:vector<u8> = *string::bytes(&string::utf8(b""));
        let (i, len) = (0u64, vector::length(&my_sales));
        while (i < len) {
            let onSale:&OnSale = vector::borrow(my_sales, i);
            vector::append(&mut vec_out, object::uid_to_bytes(onSale.id));
            vector::push_back(&mut vec_out, byte_comma);
            vector::append(&mut vec_out, *string::bytes(value.name));
            vector::push_back(&mut vec_out, byte_comma);
            vector::append(&mut vec_out, numbers_to_ascii_vector(value.num));
            vector::push_back(&mut vec_out, byte_comma);
            vector::append(&mut vec_out, numbers_to_ascii_vector(value.price));
            vector::push_back(&mut vec_out, byte_comma);
            vector::append(&mut vec_out, *string::bytes(value.type));
            vector::push_back(&mut vec_out, byte_comma);
            vector::append(&mut vec_out, value.owner);
            vector::push_back(&mut vec_out, byte_comma);
            vector::append(&mut vec_out, numbers_to_ascii_vector(value.onsale_time));
            i = i + 1
        };
        vec_out
    }

    public entry unlist_game_item (
        global:&mut MarketGlobal, 
        meta: &mut MetaIdentity, 
        owner: address,
        name: String,
        num: u64,
        clock: &Clock, 
        ctx: &mut TxContext
    ) {
        // todo:anyone can unlist item out of deadline
        assert!(owner == tx_context::sender(TxContext), ERR_NOT_OWNER);
        assert!(linked_table::contains(&global.market_sales, owner), ERR_SALES_NOT_EXIST);
        let his_sales = linked_table::borrow_mut(&mut global.market_sales, owner);
        let (i, len) = (0u64, vector::length(&his_sales));
        while (i < len) {
            let onSale:&OnSale = vector::borrow(his_sales, i);
            if (onSale.name == name && onSale.num == num && onSale.price <= value(merge_coins)) {
                let sale = vector::remove(his_sales, i);
                if (vector::length(&his_sales) == 0) {
                    linked_table::remove(&mut global.market_sales, owner);
                };
                let balance = coin::into_balance<SUI>(
                    coin::split<SUI>(&mut merged_coin, sale.price, ctx);
                );
                balance::join(&mut global.balance_SUI, balance);
                if (coin::value(&merged_coin) > 0) {
                    transfer::public_transfer(merged_coin, tx_context::sender(ctx))
                } else {
                    destroy_zero(merged_coin);
                };
                tree_of_life::fill_items(meta, name, num);
                break;
            };
            i = i + 1
        };
    }

    public entry purchase_game_item (
        global:&mut MarketGlobal, 
        meta: &mut MetaIdentity, 
        owner: address,
        name: String,
        num: u64,
        payment:vector<Coin<SUI>>,
        clock: &Clock, 
        ctx: &mut TxContext) {
        let merged_coin = merge_coins(coins, ctx);
        assert!(linked_table::contains(&global.market_sales, owner), ERR_SALES_NOT_EXIST);
        let his_sales = linked_table::borrow_mut(&mut global.market_sales, owner);
        let (i, len) = (0u64, vector::length(&his_sales));
        while (i < len) {
            let onSale:&OnSale = vector::borrow(his_sales, i);
            if (onSale.name == name && onSale.num == num && onSale.price <= value(merge_coins)) {
                let sale = vector::remove(his_sales, i);
                if (vector::length(&his_sales) == 0) {
                    linked_table::remove(&mut global.market_sales, owner);
                };
                let balance = coin::into_balance<SUI>(
                    coin::split<SUI>(&mut merged_coin, sale.price, ctx);
                );
                balance::join(&mut global.balance_SUI, balance);
                if (coin::value(&merged_coin) > 0) {
                    transfer::public_transfer(merged_coin, tx_context::sender(ctx))
                } else {
                    destroy_zero(merged_coin);
                };
                tree_of_life::fill_items(meta, name, num);
                break;
            };
            i = i + 1
        };
    }

    public entry list_game_item (
        global: &mut MarketGlobal,
        meta: &mut MetaIdentity,
        price: u64,
        name: String,
        num: u64,
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
            let new_sales = vector::new<OnSale>();
            let new_sale = new_sale(name, num, price, clock, type, ctx);
            vector::push_back(&mut new_sales, new_sale);
            linked_table::push_back(sales, owner, new_sales);
        };
    }

    fun numbers_to_ascii_vector(val: u16): vector<u8> {
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