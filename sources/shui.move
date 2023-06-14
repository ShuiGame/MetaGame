module hello_world::shui {
    use std::option::{Self, Option};
    use sui::coin::{Self, Coin, TreasuryCap, destroy_zero};
    use sui::transfer;
    use sui::object::{Self, ID, UID};
    use sui::tx_context::{Self, TxContext};
    use std::vector::{Self};
    use std::type_name::{get, into_string};
    use std::string;
    use std::ascii::String;
    use sui::balance::{Self, Supply, Balance};
    use sui::sui::SUI;
    use sui::pay;
    use hello_world::race::{Self};
    use hello_world::level::{Self};
    use hello_world::gift::{Self};
    use hello_world::avatar::{Self};
    use sui::table::{Self, Table};
    use sui::bag::{Self, Bag};


    const TYPE_CREATOR:u8 = 0;
    const TYPE_MEMBER:u8 = 1;
    const TYPE_IDO:u8 = 2;
    const TYPE_AIRDROP:u8 = 3;
    const TYPE_PUBLIC:u8 = 4;

    const ERR_CHARACTOR_CREATED:u64 = 0x001;
    const ERR_BINDED:u64 = 0x002;
    const ERR_UNBINDED:u64 = 0x003;
    const ERR_NO_PERMISSION:u64 = 0x004;
    const ERR_NOT_IN_WHITELIST:u64 = 0x005;
    const EXCEED_SWAP_LIMIT:u64 = 0x006;
    const TOTAL_SUPPLY: u64 = 2_100_000_000;
    const AIRDROP_SUPPLY:u64 = 500_000_000;
    const GAME_GAME_SUPPLY:u64 = 1_000_000_000;
    const GOLD_RESERVE_SUPPLY:u64 = 300_000_000;
    const EXCHANGE_SUPPLY:u64 = 100_000_000;
    const FOUNDATION_SUPPLY:u64 = 100_000_000;
    const DAO_SUPPLY:u64 = 100_000_000;
    const AMOUNT_CREATOR_SWAP:u64 = 5_000_000;
    const AMOUNT_PER_MEMBER_SWAP_LIMIT:u64 = 500_000;
    const AMOUNT_PER_IDO_SWAP_LIMIT:u64 = 100_000;
    const AMOUNT_PER_AIRDROP_SWAP_LIMIT:u64 = 10_000;

    const CREATOR_SWAP_RATIO:u64 = 1000;
    const MEMBER_SWAP_RATIO:u64 = 500;
    const IDO_SWAP_RATIO:u64 = 250;
    const AIRDROP_SWAP_RATIO:u64 = 250;
    const PUBLIC_SWAP_RATIO:u64 = 100;

    struct SHUI has drop {}
    struct Global has key {
        id: UID,
        supply: u64,
        balance: Balance<SUI>,
        creator: address,
        members: Table<address, bool>,
        tables: Table<u8, Table<address, bool>>,
        ido_whitelist: Table<address, bool>,
        airdrop_whitelist: Table<address, bool>,
        swap_amount_records: Table<address, u64>,
        minted_members_count: u16,
        minted_ido_count: u16,
        minted_airdrop_count: u16,
    }

    struct MetaIdentify has key, store {
        // preserve 0-20000 for airdrop
        id:UID,

        // changeto ID
        metaId:ID,
        name:string::String,
        charactor: Option<Inscription>,
        bind:Option<Bind>,
        // wallet:address // is it necessay??
    }

    struct Faucet has key {
        id: UID,
        bags: Bag,
        creator: address
    }

    struct Inscription has store {
        name: string::String,
        gender: string::String,
        avatar: avatar::Avatar,
        race: race::Race,
        level: level::Level,
        gift: gift::Gift,
    }

    struct Bind has key, store {
        id:UID,
        status:bool,
        phone:string::String
    }

    fun init(witness: SHUI, ctx: &mut TxContext) {
        let (adminCap, metadata) = coin::create_currency(witness, 
            6,
            b"shui",
            b"shui",
            b"desc",
            option::none(), 
            ctx);
        transfer::public_freeze_object(metadata);
        let global = Global {
            id: object::new(ctx),
            creator: tx_context::sender(ctx),
            supply: TOTAL_SUPPLY,
            balance: balance::zero(),
            tables: get_tables(ctx),
            members: table::new<address, bool>(ctx),
            ido_whitelist: table::new<address, bool>(ctx),
            airdrop_whitelist: table::new<address, bool>(ctx),
            swap_amount_records: table::new<address, u64>(ctx),
            minted_members_count: 0,
            minted_ido_count: 0,
            minted_airdrop_count: 0,
        };
        transfer::share_object(global);
        transfer::share_object(
            Faucet {
                id: object::new(ctx),
                bags: get_bags(ctx),
                creator: tx_context::sender(ctx),
            }
        );
        transfer::public_transfer(adminCap, tx_context::sender(ctx));
    }

    fun get_tables(ctx: &mut TxContext): Table<u8, Table<address, bool>> {
        let tables = table::new<u8, Table<address, bool>>(ctx);
        table::add(&mut tables, TYPE_CREATOR, table::new<address, bool>(ctx));
        table::add(&mut tables, TYPE_MEMBER, table::new<address, bool>(ctx));
        table::add(&mut tables, TYPE_IDO, table::new<address, bool>(ctx));        
        table::add(&mut tables, TYPE_AIRDROP, table::new<address, bool>(ctx));
        table::add(&mut tables, TYPE_PUBLIC, table::new<address, bool>(ctx));
        tables
    }

    fun get_bags(ctx: &mut TxContext): Bag {
        let coins = bag::new(ctx);
        bag::add(&mut coins, into_string(get<SHUI>()), balance::create_supply(SHUI {}));
        coins
    }

    public fun createMetaIdentify(name:string::String, ctx: &mut TxContext) : MetaIdentify{
        // exist judgement
        // bind judgement
        let obj_id = object::new(ctx); 

        // tbd
        let game_id = object::uid_to_inner(&obj_id);
        MetaIdentify {
            id:obj_id,
            metaId:game_id,
            name:name,
            charactor:option::none(),
            bind:option::none(),
        }
    }

    fun createCharactor(
        identity:&mut MetaIdentify,
        name: string::String,
        gender: string::String,
        avatar: avatar::Avatar,
        race: race::Race,
        gift: gift::Gift,
        _: &mut TxContext) {
        assert!(!option::is_some(&identity.charactor), ERR_CHARACTOR_CREATED);
        let new_cha = Inscription{
            name:name,
            gender: gender,
            avatar: avatar,
            race: race,
            level: level::new_level(),
            gift: gift,
        };
        option::fill(&mut identity.charactor, new_cha);
    }

    public fun mint(treasuryCap:&mut TreasuryCap<SHUI>, amount:u64, ctx:&mut TxContext) : Coin<SHUI>{
        coin::mint(treasuryCap, amount, ctx)
    }

    public fun mint_coins<T>(
        faucet: &mut Faucet,
        amount: u64,
        ctx: &mut TxContext
    ): Coin<T> {
        let coin_name = into_string(get<T>());
        assert!(
            bag::contains_with_type<String, Supply<T>>(&faucet.bags, coin_name),
            0x04
        );
        let mut_supply = bag::borrow_mut<String, Supply<T>>(
            &mut faucet.bags,
            coin_name
        );
        let minted_balance = balance::increase_supply(
            mut_supply,
            amount
        );
        coin::from_balance(minted_balance, ctx)
    }

    public entry fun creator_swap<T> (faucet: &mut Faucet, global: &mut Global, sui_pay_amount:u64, coins:vector<Coin<SUI>>, ctx:&mut TxContext) {
        let radio = CREATOR_SWAP_RATIO;
        let limit = AMOUNT_CREATOR_SWAP;
        assert!(global.creator == tx_context::sender(ctx), ERR_NO_PERMISSION);
        swap_internal<T>(faucet, global, sui_pay_amount, coins, radio, limit, ctx);
    }

    public entry fun members_swap<T> (faucet: &mut Faucet, global: &mut Global, sui_pay_amount:u64, coins:vector<Coin<SUI>>, ctx:&mut TxContext) {
        let radio = MEMBER_SWAP_RATIO;
        let limit = AMOUNT_PER_MEMBER_SWAP_LIMIT;
        assert!(table::contains(&global.members, tx_context::sender(ctx)), ERR_NOT_IN_WHITELIST);
        swap_internal<T>(faucet, global, sui_pay_amount, coins, radio, limit, ctx);
    }

    public entry fun ido_swap<T> (faucet: &mut Faucet, global: &mut Global, sui_pay_amount:u64, coins:vector<Coin<SUI>>, ctx:&mut TxContext) {
        let radio = IDO_SWAP_RATIO;
        let limit = AMOUNT_PER_IDO_SWAP_LIMIT;
        assert!(table::contains(&global.ido_whitelist, tx_context::sender(ctx)), ERR_NOT_IN_WHITELIST);
        swap_internal<T>(faucet, global, sui_pay_amount, coins, radio, limit, ctx);
    }

    public entry fun airdrop_swap<T> (faucet: &mut Faucet, global: &mut Global, sui_pay_amount:u64, coins:vector<Coin<SUI>>, ctx:&mut TxContext) {
        let radio = AIRDROP_SWAP_RATIO;
        let limit = AMOUNT_PER_AIRDROP_SWAP_LIMIT;
        assert!(table::contains(&global.airdrop_whitelist, tx_context::sender(ctx)), ERR_NOT_IN_WHITELIST);
        swap_internal<T>(faucet, global, sui_pay_amount, coins, radio, limit, ctx);
    }

    public entry fun public_swap<T> (faucet: &mut Faucet, global: &mut Global, sui_pay_amount:u64, coins:vector<Coin<SUI>>, ctx:&mut TxContext) {
        let radio = PUBLIC_SWAP_RATIO;
        let limit = TOTAL_SUPPLY;
        swap_internal<T>(faucet, global, sui_pay_amount, coins, radio, limit, ctx);
    }

    public fun swap_internal<T> (faucet: &mut Faucet, global: &mut Global, sui_pay_amount:u64, coins:vector<Coin<SUI>>, radio:u64, limit:u64, ctx:&mut TxContext) {
        let account = tx_context::sender(ctx);
        let merged_coin = vector::pop_back(&mut coins);
        pay::join_vec(&mut merged_coin, coins);

        // TODO:CHANGE TO LEFT
        assert!(coin::value(&merged_coin) <= limit, EXCEED_SWAP_LIMIT);

        let balance = coin::into_balance<SUI>(
            coin::split<SUI>(&mut merged_coin, sui_pay_amount, ctx)
        );

        balance::join(&mut global.balance, balance);

        // transfer remain to account
        if (coin::value(&merged_coin) > 0) {
            transfer::public_transfer(merged_coin, tx_context::sender(ctx))
        } else {
            destroy_zero(merged_coin)
        };

        // transfer SHUI to account 1:500
        let shui_amount = sui_pay_amount * radio;
        let coins = mint_coins<SHUI>(faucet, shui_amount, ctx);
        transfer::public_transfer(coins, tx_context::sender(ctx));

        // record the swaped amount
        table::add(&mut global.swap_amount_records, account, shui_amount);
    }

    public entry fun burn<T>(treasury: &mut TreasuryCap<SHUI>, coin: Coin<SHUI>) {
        coin::burn(treasury, coin);
    }

    public entry fun bindMeta(meta:&mut MetaIdentify, phone:string::String, ctx: &mut TxContext) {
        // confition: unbinded
        if (option::is_some(&meta.bind)) {
            let bind_read = option::borrow(&meta.bind);
            assert!(bind_read.status == false, ERR_BINDED);
        };
        option::fill(&mut meta.bind, Bind {
            id:object::new(ctx),       
            phone:phone,
            status:true
        });
    }

    public entry fun unbindMeta(meta:&mut MetaIdentify) {
        assert!(option::is_some(&meta.bind), ERR_UNBINDED);
        let bind_read = option::borrow(&meta.bind);
        assert!(bind_read.status == true, ERR_BINDED);
        let bind_read = option::borrow_mut(&mut meta.bind);
        bind_read.status = false;
    }

    public entry fun deleteMeta(meta: MetaIdentify) {
        let MetaIdentify {id, metaId:_, name:_, charactor, bind} = meta;
        object::delete(id);
        let bind = option::destroy_some(bind);
        let cha = option::destroy_some(charactor);
        let Bind { id, status:_, phone:_} = bind;
        object::delete(id);
        let Inscription {name:_, gender:_, avatar:_ ,race:_ ,level:_,gift:_} = cha;
    }

    public entry fun transferMeta(meta: MetaIdentify, receiver:address) {
        unbindMeta(&mut meta);
        transfer::public_transfer(meta, receiver);
    }

    public entry fun add_to_whitelist(global: &mut Global, account: address, list_type:u8, ctx: &mut TxContext,) {
        assert!(global.creator == tx_context::sender(ctx), ERR_NO_PERMISSION);
        let tablelist = table::borrow_mut<u8, Table<address, bool>>(
            &mut global.tables,
            list_type
        );
        table::add(tablelist, account, true);
    }

    public entry fun set_whitelists(global: &mut Global, whitelist: vector<address>, list_type:u8, ctx: &mut TxContext,) {
        assert!(global.creator == tx_context::sender(ctx), ERR_NO_PERMISSION);
        let (i, len) = (0u64, vector::length(&whitelist));
        let tablelist = table::borrow_mut<u8, Table<address, bool>>(
            &mut global.tables,
            list_type
        );
        while (i < len) {
            let account = vector::pop_back(&mut whitelist);
            table::add(tablelist, account, true);
            i = i + 1
        };
    }
}