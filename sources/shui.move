module hello_world::shui {
    use std::option::{Self, Option};
    use sui::coin::{Self, Coin, TreasuryCap};
    use sui::transfer;
    use sui::object::{Self, ID, UID};
    use sui::tx_context::{Self, TxContext};
    use std::string;
    use sui::balance::{Self, Balance};
    // use sui::display;   
    use hello_world::race::{Self};
    use hello_world::level::{Self};
    use hello_world::gift::{Self};
    use hello_world::avatar::{Self};
    // use sui::package;

    const ERR_CHARACTOR_CREATED:u64 = 0x001;
    const ERR_BINDED:u64 = 0x002;
    const ERR_UNBINDED:u64 = 0x003;

    // to be determined
    const MAX_SUPPLY: u16 = 10000;
    
    struct Global has key {
        id: UID,
        creator: address,
        supply: u16,
        balance: Balance<SHUI>,
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

    struct SHUI has drop{}

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
            supply: MAX_SUPPLY,
            balance: balance::zero(),
        };
        transfer::share_object(global);
        transfer::public_transfer(adminCap, tx_context::sender(ctx));
    }

    public fun createMetaIdentify(name:string::String, ctx: &mut TxContext) : MetaIdentify{
        // exist judgement
        // bind judgement
        let obj_id = object::new(ctx); 
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
    
    public fun mint(treasuryCap: &mut TreasuryCap<SHUI>, amount:u64, ctx:&mut TxContext) :Coin<SHUI>{
        coin::mint(treasuryCap, amount, ctx)
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
        // confition: binded
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
}