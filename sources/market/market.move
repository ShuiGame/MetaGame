module shui_module::market {
    use std::ascii;
    use std::string::{Self, String, utf8};
    use std::type_name::{Self, into_string};
    use std::vector;
    use sui::sui::{SUI};
    use sui::coin::{Self, Coin, value};
    use sui::event;
    use sui::kiosk::{Self, KioskOwnerCap, Kiosk};
    use sui::object::Self;
    use sui::transfer;
    use sui::transfer_policy::{Self as policy, TransferPolicy};
    use sui::tx_context::{Self, TxContext, sender};
    use sui::dynamic_field;

    use shui_module::comparator::{compare, is_equal};
    use shui_module::items_credential::{Self, GameItemsCredential};
    use shui_module::metaIdentity::MetaIdentity;
    use shui_module::royalty_policy::{Self, calculate_royalty};
    use shui_module::tree_of_life::Self;

    const ERR_INSUFFICIENT_ROYALTY_COIN: u64 = 0x01;

    struct MARKET has drop {}

    struct ItemListed has copy, drop {
        kioskId: vector<u8>,
        name: String,
        index: u64,
        owner: address,
        item_id: address,
        price: u64,
        num: u64,
        kioskcap: address
    }

    struct ItemPurchased has copy, drop {
        kioskId: vector<u8>,
        owner: address,
        buyer: address,
        name: String,
        num: u64
    }

    // Maker place the order
    // Create a new kiosk to escrow nft
    public fun list<Obj: key + store>(
        item: Obj,
        price: u64,
        ctx: &mut TxContext
    ) {
        let (kiosk, cap) = inner_list(item, price, utf8(b""), ctx);
        transfer::public_transfer(kiosk, tx_context::sender(ctx));
        transfer::public_transfer(cap, tx_context::sender(ctx));
    }

    // Taker takes the order
    // According to the policy, exchange coin<SUI> to kiosk and withdraw nft
    public fun purchase<Obj: key + store>(
        policy: &TransferPolicy<Obj>,
        kiosk: &mut kiosk::Kiosk,
        addr: address,
        coins: vector<Coin<SUI>>,
        royalty_coins: vector<Coin<SUI>>,
        ctx: &mut TxContext
    ) {
        let merged_coin = merge_coins(coins, ctx);
        let merged_royalty = merge_coins(royalty_coins, ctx);

        let royalty_fee = calculate_royalty<Obj>(policy, value(&merged_coin));
        assert!(value(&merged_royalty) >= royalty_fee, ERR_INSUFFICIENT_ROYALTY_COIN);

        let obj = inner_purchase(
            policy,
            kiosk,
            addr,
            merged_coin,
            &mut merged_royalty,
            ctx
        );

        if (value(&merged_royalty) > 0) {
            transfer::public_transfer(merged_royalty, sender(ctx))
        } else {
            coin::destroy_zero(merged_royalty);
        };

        transfer::public_transfer(obj, tx_context::sender(ctx))
    }

    // Marker complete the order
    // Take Coin<SUI> from kiosk to self and delete kiosk
    public fun complete(
        kiosk: kiosk::Kiosk,
        cap: kiosk::KioskOwnerCap,
        ctx: &mut TxContext
    ) {
        let sui = kiosk::close_and_withdraw(kiosk, cap, ctx);
        transfer::public_transfer(sui, tx_context::sender(ctx));
    }

    // Marker cancle the order
    // Take nft from kiosk back self and delete kiosk
    public fun unlist<Obj: key + store>(
        kiosk: &mut kiosk::Kiosk,
        cap: &kiosk::KioskOwnerCap,
        item: address,
        ctx: &mut TxContext
    ) {
        let nft = inner_unlist<Obj>(kiosk, cap, item);
        transfer::public_transfer(nft, tx_context::sender(ctx));
    }

    public fun list_game_items(
        meta: &mut MetaIdentity,
        total_price: u64,
        name: String,
        num: u64,
        ctx: &mut TxContext
    ): address {
        // extract and drop items
        tree_of_life::extract_drop_items(meta, name, num);

        // create virtual nft credential
        let virtualCredential = items_credential::construct(name, num, ctx);

        let addr = object::id_address(&virtualCredential);

        // list to market
        let (kiosk, cap) = inner_list(virtualCredential, total_price, name, ctx);
        transfer::public_transfer(kiosk, tx_context::sender(ctx));
        transfer::public_transfer(cap, tx_context::sender(ctx));

        addr
    }

    public fun purchase_game_items(
        meta:&mut MetaIdentity,
        policy: &TransferPolicy<GameItemsCredential>,
        kiosk: &mut kiosk::Kiosk,
        addr: address,
        coins:vector<Coin<SUI>>,
        royalty_coins: vector<Coin<SUI>>,
        ctx: &mut TxContext
    ) {
        let merged_coin = merge_coins(coins, ctx);
        let merged_royalty = merge_coins(royalty_coins, ctx);

        let royalty_fee = calculate_royalty<GameItemsCredential>(policy, value(&merged_coin));
        assert!(value(&merged_royalty) >= royalty_fee, ERR_INSUFFICIENT_ROYALTY_COIN);

        let game_credential = inner_purchase(
            policy,
            kiosk,
            addr,
            merged_coin,
            &mut merged_royalty,
            ctx
        );
        if (value(&merged_royalty) > 0) {
            transfer::public_transfer(merged_royalty, sender(ctx))
        } else {
            coin::destroy_zero(merged_royalty);
        };

        let (name, num) = items_credential::destruct(game_credential);

        // create and add to items
        tree_of_life::fill_items(meta, name, num);
    }

    public fun unlist_game_items(
        kiosk: &mut kiosk::Kiosk,
        cap: &kiosk::KioskOwnerCap,
        meta:&mut MetaIdentity,
        virtual_item: address,
        _ctx: &mut TxContext
    ) {

        let game_credential = inner_unlist(
            kiosk,
            cap,
            virtual_item,
        );

        let (name, num) = items_credential::destruct(game_credential);

        // create and add to items
        tree_of_life::fill_items(meta, name, num);
    }

    public fun get_collection_name<Obj>(
        item_name: String
    ): String {
        let market_type_name = type_name::get<MARKET>();
        let market_contract = type_name::get_address(&market_type_name);
        let boat_ticket = ascii::string(b"boat_ticket");
        let shui_ticket = ascii::string(b"shui_ticket");
        let items_credential = ascii::string(b"items_credential");

        let obj_type_name = type_name::get<Obj>();
        let obj_contract = type_name::get_address(&obj_type_name);
        let obj_module = type_name::get_module(&obj_type_name);

        if (is_equal(&compare(&obj_contract, &market_contract))) {
            if (is_equal(&compare(&obj_module, &boat_ticket))) {
                return string::utf8(b"nft")
            };

            if (is_equal(&compare(&obj_module, &shui_ticket))) {
                return string::utf8(b"nft")
            };

            if (is_equal(&compare(&obj_module, &items_credential))) {
                return item_name
            }
        };

        return string::utf8(ascii::into_bytes(into_string(obj_type_name)))
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

    fun inner_list<Obj: key + store>(
        item: Obj,
        price: u64,
        maybe_game_items_name: String,
        ctx: &mut TxContext
    ): (Kiosk, KioskOwnerCap) {
        let collection_name = get_collection_name<Obj>(maybe_game_items_name);

        let (kiosk, cap) = kiosk::new(ctx);
        kiosk::set_allow_extensions(&mut kiosk, &cap, true);
        dynamic_field::add(kiosk::uid_mut(&mut kiosk), true, collection_name);

        event::emit(
            ItemListed {
                kioskId: object::uid_to_bytes(kiosk::uid(&kiosk)),
                name: collection_name,
                index: 0,
                owner: tx_context::sender(ctx),
                price: price,
                item_id: object::id_address(&item),
                num: 1,
                kioskcap: object::id_address(&cap),
            }
        );

        kiosk::place_and_list(&mut kiosk, &cap, item, price);

        return (kiosk, cap)
    }

    fun inner_purchase<Obj: key + store>(
        policy: &TransferPolicy<Obj>,
        kiosk: &mut kiosk::Kiosk,
        addr: address,
        merged_coin: Coin<SUI>,
        merged_royalty: &mut Coin<SUI>,
        ctx: &mut TxContext
    ): Obj {
        let collection_name = dynamic_field::remove(kiosk::uid_mut(kiosk), true);

        let id = object::id_from_address(addr);


        let (obj, transferRequst) = kiosk::purchase<Obj>(kiosk, id, merged_coin);

        royalty_policy::pay(policy, &mut transferRequst, merged_royalty, ctx);

        policy::confirm_request(policy, transferRequst);

        event::emit(
            ItemPurchased {
                kioskId: object::uid_to_bytes(kiosk::uid(kiosk)),
                owner: kiosk::owner(kiosk),
                buyer: tx_context::sender(ctx),
                name: collection_name,
                num: 1
            }
        );

        return obj
    }

    fun inner_unlist<Obj: key + store>(
        kiosk: &mut kiosk::Kiosk,
        cap: &kiosk::KioskOwnerCap,
        item: address,
    ): Obj {
        return kiosk::take<Obj>(kiosk, cap, object::id_from_address(item))
    }
}