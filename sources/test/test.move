// Copyright 2023 ComingChat Authors. Licensed under Apache-2.0 License.
#[test_only]
module shui_module::airdrop_test {
    use std::vector;
    use std::string::{Self, utf8};
    use sui::clock::{Self, Clock};
    use std::debug::print;
    use shui_module::items_credential;
    use sui::coin::{Self, Coin};
    use sui::test_scenario::{
        Scenario, next_tx, begin, end, ctx, take_shared, return_shared, take_from_sender,return_to_sender,take_from_address,
        next_epoch
    };
    use sui::transfer_policy_tests as test;
    use sui::transfer_policy::{
        Self as policy,
        TransferPolicy,
        TransferPolicyCap,
        TransferRequest
    };

    use sui::sui::SUI;
    use sui::tx_context;
    use sui::pay;
    use shui_module::items::{Self};
    use shui_module::shui::{Self};
    use sui::package;
    use shui_module::royalty_policy;
    use shui_module::metaIdentity::{Self};
    use shui_module::airdrop::{Self};
    use shui_module::founder_team_reserve::{Self};
    use shui_module::swap::{Self};
    use shui_module::tree_of_life::{Self};
    use shui_module::crypto::{Self};
    use shui_module::market2;
    use shui_module::boat_ticket::{Self};
    use shui_module::market::{Self};
    use shui_module::mission;
    use sui::object::{Self};
    use sui::kiosk::{Self};

    use sui::hex::{Self};

    const DAY_IN_MS: u64 = 86_400_000;
    const HOUR_IN_MS: u64 = 3_600_000;
    const START:u64 = 80000;

    struct OTW has drop {}

    // utilities
    fun scenario(): Scenario { begin(@account) }

    fun claim_airdrop(test: &mut Scenario, clock:&clock::Clock) {
        let airdropGlobal = take_shared<airdrop::AirdropGlobal>(test);
        let meta = take_from_sender<metaIdentity::MetaIdentity>(test);
        let missionGlobal = take_shared<mission::MissionGlobal>(test);
        airdrop::claim_airdrop(&mut missionGlobal, &mut airdropGlobal, &meta, clock, ctx(test));
        return_to_sender(test, meta);
        return_shared(airdropGlobal);
        return_shared(missionGlobal);
    }

    fun water_down(test: &mut Scenario, user:address, clock:&clock::Clock) {
        let treeGlobal = take_shared<tree_of_life::TreeGlobal>(test);
        let missionGlobal = take_shared<mission::MissionGlobal>(test);
        let meta = take_from_sender<metaIdentity::MetaIdentity>(test);
        let coin = take_from_address<Coin<shui::SHUI>>(test, user);
        let coins = vector::empty<Coin<shui::SHUI>>();
        vector::push_back(&mut coins, coin);
        tree_of_life::water_down(&mut missionGlobal, &mut treeGlobal, &mut meta, coins, clock, ctx(test));
        return_to_sender(test, meta);
        return_shared(treeGlobal);
        return_shared(missionGlobal);
    }

    fun print_items(itemGlobal: &items::ItemGlobal, test: &mut Scenario) {
        let meta = take_from_sender<metaIdentity::MetaIdentity>(test);
        let items_info = metaIdentity::get_items_info(&meta, itemGlobal);
        print(&items_info);
        return_to_sender(test, meta);
    }

    fun print_missions(test: &mut Scenario, clock: &Clock) {
        let missionGlobal = take_shared<mission::MissionGlobal>(test);
        let meta = take_from_sender<metaIdentity::MetaIdentity>(test);
        let mission_list = mission::query_mission_list(&missionGlobal, &mut meta, clock);
        print(&string::utf8(b"----------Mission_list----------"));
        print(&mission_list);
        print(&string::utf8(b"----------End----------"));
        return_to_sender(test, meta);
        return_shared(missionGlobal);
    }

    fun print_balance(test: &mut Scenario, user:address) {
        let coin = take_from_address<Coin<shui::SHUI>>(test, user);
        let value = coin::value(&coin);
        print(&string::utf8(b"account shui:"));
        print(&value);
        pay::keep(coin, ctx(test));
    }

    // fun print_ids(test: &Scenario) {
    //     let ids = ids_for_sender<Coin<shui::SHUI>>(test);
    //     print(&ids);
    // }

    // #[test]
    fun test_crypto() {
        let scenario = scenario();
        let test = &mut scenario;
        let admin = @account;

        // init package
        next_tx(test, admin);
        {
            let res = crypto::test_ecds();
            print(&string::utf8(b"test:"));
            print(&res);
            // print(hex::decode(b"This is a test of the tsunami alert system."));
        };
        end(scenario);
    }

    // #[test]
    fun test_name_type_transfer() {
        let scenario = scenario();
        let test = &mut scenario;
        let admin = @account;

        next_tx(test, admin);
        {
            let res = tree_of_life::get_item_type_by_name(string::utf8(b"water_element_holy"));
            let res2 = tree_of_life::get_element_type_by_name(string::utf8(b"water_element_holy"));
            let res3 = tree_of_life::get_item_type_by_name(string::utf8(b"fragment_holy"));
            print(&res);
            print(&res2);
            print(&res3);
        };
        end(scenario);
    }

    #[test]
    fun test_market() {
        let scenario = scenario();
        let test = &mut scenario;
        let admin = @account;
        let clock = clock::create_for_testing(ctx(test));

        // init package
        next_tx(test, admin);
        {
            shui::init_for_test(test);
            metaIdentity::init_for_test(ctx(test));
            airdrop::init_for_test(ctx(test));
            swap::init_for_test(ctx(test));
            founder_team_reserve::init_for_test(ctx(test));
            tree_of_life::init_for_test(ctx(test));
            items::init_for_test(ctx(test));
            mission::init_for_test(ctx(test));
            market2::init_for_test(ctx(test));
        };

        // register meta
        next_tx(test, admin);
        {
            let global = take_shared<metaIdentity::MetaInfoGlobal>(test);
            metaIdentity::mintMeta(
                &mut global,
                string::utf8(b"sean"),
                string::utf8(b"13262272231"),
                string::utf8(b"448651346@qq.com"),
                admin,
                ctx(test)
            );
            return_shared(global)
        };

        next_tx(test, admin);
        {
            boat_ticket::init_for_test(ctx(test));
        };

        next_tx(test, admin);
        {
            let missionGlobal = take_shared<mission::MissionGlobal>(test);
            mission::init_missions(&mut missionGlobal, &clock, ctx(test));
            return_shared(missionGlobal);
            clock::increment_for_testing(&mut clock, 2 * DAY_IN_MS + 600000);
            next_epoch(test, admin);
            print_missions(test, &clock);
        };

        next_tx(test, admin);
        {
            let itemGlobal = take_shared<items::ItemGlobal>(test);
            let i = 0;
            while (i < 5) {
                clock::increment_for_testing(&mut clock, 8 * HOUR_IN_MS + 1);
                water_down(test, admin, &clock);
                next_epoch(test, admin);
                i = i + 1;
            };
            return_shared(itemGlobal);
            next_epoch(test, admin);
            print_missions(test, &clock);
        };

        next_tx(test, admin);
        {
            let missionGlobal = take_shared<mission::MissionGlobal>(test);
            let meta = take_from_sender<metaIdentity::MetaIdentity>(test);
            mission::claim_mission(&mut missionGlobal, utf8(b"water down"), &mut meta);
            next_epoch(test, admin);
            return_to_sender(test, meta);
            return_shared(missionGlobal);
            next_epoch(test, admin);
            print_missions(test, &clock);
        };

        // boat ticket test
        next_tx(test, admin);
        {
            let ticketGlobal = take_shared<boat_ticket::BoatTicketGlobal>(test);
            boat_ticket::claim_ticket(&mut ticketGlobal, ctx(test));
            return_shared(ticketGlobal);
            next_epoch(test, admin);
            let ticket = take_from_sender<boat_ticket::BoatTicket>(test);
            let addr = object::id_address(&ticket);

            market::list(ticket, 10, ctx(test));
            next_epoch(test, admin);

            let kiosk = take_from_sender<kiosk::Kiosk>(test);
            let cap = take_from_sender<kiosk::KioskOwnerCap>(test);
            market::unlist<boat_ticket::BoatTicket>(&mut kiosk, &cap, addr, ctx(test));
            return_to_sender(test, kiosk);
            return_to_sender(test, cap);
            next_epoch(test, admin);
        };

        // water down
        next_tx(test, admin);
        {
            let itemGlobal = take_shared<items::ItemGlobal>(test);
            let i = 0;
            while (i < 60) {
                clock::increment_for_testing(&mut clock, 8 * HOUR_IN_MS + 1);
                water_down(test, admin, &clock);
                next_epoch(test, admin);
                i = i + 1;
            };
            print_items(&itemGlobal, test);
            return_shared(itemGlobal);
        };

        // open fruit for fragment
        next_tx(test, admin);
        {
            print(&string::utf8(b"open some fruits"));
            let itemGlobal = take_shared<items::ItemGlobal>(test);
            tx_context::increment_epoch_timestamp(ctx(test), 4);
            let i = 0;
            let loop_num = 5;
            while (i < loop_num) {
                let meta = take_from_sender<metaIdentity::MetaIdentity>(test);
                tree_of_life::open_fruit(&mut meta, ctx(test));
                return_to_sender(test, meta);
                next_epoch(test, admin);
                i = i + 1;
                next_epoch(test, admin);
            };
            print_items(&itemGlobal, test);
            return_shared(itemGlobal);
        };

        next_tx(test, admin);
        {
            print(&string::utf8(b"-----------------start market2 test---------------"));
            let market_global =  take_shared<market2::MarketGlobal>(test);
            let itemGlobal = take_shared<items::ItemGlobal>(test);
            let meta = take_from_sender<metaIdentity::MetaIdentity>(test);
            market2::list_game_item(&mut market_global, &mut meta, utf8(b"fruit"), 1,  1, &clock, ctx(test));
            return_to_sender(test, meta);


            let res = market2::get_market_sales(&market_global, &clock);
            print(&res);
            return_shared(market_global);
            next_epoch(test, admin);

            print_items(&itemGlobal, test);
            return_shared(itemGlobal);
        };

        // boat_ticket market test
        // next_tx(test, admin);
        // {
        //     print(&string::utf8(b"start market test"));
        //     let publisher = package::test_claim(OTW {}, ctx(test));
        //     royalty_policy::new_royalty_policy<boat_ticket::BoatTicket>(
        //         &mut publisher,
        //         100, // 1%
        //         ctx(test)
        //     );

        //     let ticketGlobal = take_shared<boat_ticket::BoatTicketGlobal>(test);
        //     boat_ticket::claim_ticket(&mut ticketGlobal, ctx(test));
        //     next_epoch(test, admin);
        //     let ticket = take_from_sender<boat_ticket::BoatTicket>(test);
        //     let addr = object::id_address(&ticket);
        //     market::list(ticket, 10000, ctx(test));
        //     next_epoch(test, admin);

        //     let policy = take_shared(test);
        //     let kiosk = take_from_sender<kiosk::Kiosk>(test);
        //     let payment = coin::mint_for_testing<SUI>(10000, ctx(test));
        //     let royalty = coin::mint_for_testing<SUI>(100, ctx(test));
            
        //     let coins = vector::empty<coin::Coin<SUI>>();
        //     vector::push_back(&mut coins, payment);
        //     let royalty_coins = vector::empty<coin::Coin<SUI>>();
        //     vector::push_back(&mut royalty_coins, royalty);
        //     market::purchase<boat_ticket::BoatTicket>(
        //         &policy,
        //         &mut kiosk,
        //         addr,
        //         coins,
        //         royalty_coins,
        //         ctx(test)
        //     );

        //     let cap = take_from_sender<kiosk::KioskOwnerCap>(test);
        //     market::complete(kiosk, cap, ctx(test));

        //     return_shared(policy);
        //     next_epoch(test, admin);
        //     package::burn_publisher(publisher);
        //     return_shared(ticketGlobal);
        // };

        // // game item market test
        // next_tx(test, admin);
        // {
        //     print(&string::utf8(b"list to market"));
        //     let meta = take_from_sender<metaIdentity::MetaIdentity>(test);
        //     let name = string::utf8(b"fruit");
        //     let num = 12;
        //     let addr = market::list_game_items(&mut meta, 1, name, num, ctx(test));
        //     return_to_sender(test, meta);

        //     next_epoch(test,admin);

        //     let itemGlobal = take_shared<items::ItemGlobal>(test);
        //     print_items(&itemGlobal, test);
        //     return_shared(itemGlobal);

        //     next_epoch(test, admin);

        //     print(&string::utf8(b"take from market"));
        //     let meta = take_from_sender<metaIdentity::MetaIdentity>(test);
        //     let kiosk = take_from_sender<kiosk::Kiosk>(test);
        //     let cap = take_from_sender<kiosk::KioskOwnerCap>(test);
        //     market::unlist_game_items(&mut kiosk, &cap, &mut meta, addr, ctx(test));
        //     return_to_sender(test, kiosk);
        //     return_to_sender(test, cap);
        //     return_to_sender(test, meta);
        // };

        // next_tx(test, admin);
        // {
        //     print(&string::utf8(b"list to market"));
        //     let publisher = package::test_claim(OTW {}, ctx(test));

        //     royalty_policy::new_royalty_policy<items_credential::GameItemsCredential>(
        //         &mut publisher,
        //         100, // 1%
        //         ctx(test)
        //     );

        //     let meta = take_from_sender<metaIdentity::MetaIdentity>(test);
        //     let name = string::utf8(b"fruit");
        //     let num = 12;
        //     let addr = market::list_game_items(&mut meta, 10000, name, num, ctx(test));
        //     next_epoch(test,admin);

        //     let itemGlobal = take_shared<items::ItemGlobal>(test);
        //     (&itemGlobal, test);
        //     return_shared(itemGlobal);

        //     next_epoch(test, admin);

        //     print(&string::utf8(b"take from market"));
        //     let policy = take_shared(test);
        //     let kiosk = take_from_sender<kiosk::Kiosk>(test);
        //     let payment = coin::mint_for_testing<SUI>(10000, ctx(test));
        //     let royalty = coin::mint_for_testing<SUI>(100, ctx(test));

        //     let coins = vector::empty<coin::Coin<SUI>>();
        //     vector::push_back(&mut coins, payment);
        //     let royalty_coins = vector::empty<coin::Coin<SUI>>();
        //     vector::push_back(&mut royalty_coins, royalty);

        //     market::purchase_game_items(
        //         &mut meta,
        //         &policy,
        //         &mut kiosk,
        //         addr,
        //         coins,
        //         royalty_coins,
        //         ctx(test)
        //     );

        //     let cap = take_from_sender<kiosk::KioskOwnerCap>(test);
        //     market::complete(kiosk, cap, ctx(test));

        //     return_shared(policy);
        //     return_to_sender(test, meta);
        //     package::burn_publisher(publisher);

        //     next_epoch(test, admin);
        // };

        clock::destroy_for_testing(clock);  
        end(scenario);
    }

    // #[test]
    fun test_init() {
        let scenario = scenario();
        let test = &mut scenario;
        let admin = @account;
        let test_user = @0xaefddfe2f5ab51c5903146115582b7e717cad239926c8fa0fb370d724a626f84;
        let clock = clock::create_for_testing(ctx(test));

        // init package
        next_tx(test, admin);
        {
            shui::init_for_test(test);
            metaIdentity::init_for_test(ctx(test));
            airdrop::init_for_test(ctx(test));
            swap::init_for_test(ctx(test));
            founder_team_reserve::init_for_test(ctx(test));
            tree_of_life::init_for_test(ctx(test));
            items::init_for_test(ctx(test));
            market2::init_for_test(ctx(test));
        };

        // funds split
        next_tx(test, admin);
        {
            let shuiGlobal = take_shared<shui::Global>(test);

            let airdropGlobal = take_shared<airdrop::AirdropGlobal>(test);
            let reserveGlobal = take_shared<founder_team_reserve::FounderTeamGlobal>(test);
            let swapGlobal = take_shared<swap::SwapGlobal>(test);

            airdrop::init_funds_from_main_contract(&mut airdropGlobal, &mut shuiGlobal, ctx(test));
            founder_team_reserve::init_funds_from_main_contract(&mut reserveGlobal, &mut shuiGlobal, ctx(test));
            swap::init_funds_from_main_contract(&mut swapGlobal, &mut shuiGlobal, ctx(test));

            return_shared(shuiGlobal);
            return_shared(airdropGlobal);
            return_shared(reserveGlobal);
            return_shared(swapGlobal);
        };
        
        // register meta
        next_tx(test, admin);
        {
            let global = take_shared<metaIdentity::MetaInfoGlobal>(test);
            metaIdentity::mintMeta(
                &mut global,
                string::utf8(b"sean"),
                string::utf8(b"13262272231"),
                string::utf8(b"448651346@qq.com"),
                test_user,
                ctx(test)
            );
            return_shared(global)
        };

        // start clock
        next_tx(test, admin);
        {
            let airdropGlobal = take_shared<airdrop::AirdropGlobal>(test);
            let timeCap = take_from_sender<airdrop::TimeCap>(test);
            let clock = clock::create_for_testing(ctx(test));
            clock::increment_for_testing(&mut clock, START);
            airdrop::start_timing(&mut airdropGlobal, timeCap, &clock);
            return_shared(airdropGlobal);
            clock::destroy_for_testing(clock);
        };

        // airdrop test
        next_tx(test, test_user);
        {
            let airdropGlobal = take_shared<airdrop::AirdropGlobal>(test);
            let value = airdrop::get_total_shui_balance(&mut airdropGlobal);
            print(&string::utf8(b"airdrop pool:"));
            print(&value);
            return_shared(airdropGlobal);
            next_epoch(test, test_user);
            clock::increment_for_testing(&mut clock, 1 * DAY_IN_MS);
            let i = 0;
            while (i < 100) {
                claim_airdrop(test, &clock);
                next_epoch(test, test_user);
                clock::increment_for_testing(&mut clock, 1 * DAY_IN_MS + 1);
                i = i + 1;
            };
            print_balance(test, test_user);
        };

        // water down test
        next_tx(test, test_user);
        {
            let itemGlobal = take_shared<items::ItemGlobal>(test);
            let i = 0;
            while (i < 200) {
                clock::increment_for_testing(&mut clock, 8 * HOUR_IN_MS + 1);
                water_down(test, test_user, &clock);
                next_epoch(test, test_user);
                i = i + 1;
            };
            print_items(&itemGlobal, test);
            return_shared(itemGlobal);
        };

        // open fruits test
        next_tx(test, test_user);
        {
            let itemGlobal = take_shared<items::ItemGlobal>(test);
            tx_context::increment_epoch_timestamp(ctx(test), 4);
            let i = 0;
            let loop_num = 5;
            let days_min = loop_num * 3;
            print(&string::utf8(b"min_days:"));
            print(&days_min);
            while (i < loop_num) {
                let meta = take_from_sender<metaIdentity::MetaIdentity>(test);
                tree_of_life::open_fruit(&mut meta, ctx(test));
                return_to_sender(test, meta);
                next_epoch(test, test_user);
                i = i + 1;
                next_epoch(test, test_user);
            };
            print_items(&itemGlobal, test);
            return_shared(itemGlobal);
        };

        // synthesis test
        // next_tx(test, test_user);
        // {
            // let meta = take_from_sender<metaIdentity::MetaIdentity>(test);
            // tree_of_life::swap_fragment<tree_of_life::Fragment>(&mut meta, string::utf8(b"holy"));
            // return_to_sender(test, meta);
            // next_epoch(test, test_user);
            // print_items(test);
        // };

        // founder_team_reserve start
        next_tx(test, admin);
        {
            let founderTeamGlobal = take_shared<founder_team_reserve::FounderTeamGlobal>(test);
            let time_cap = take_from_sender<founder_team_reserve::TimeCap1>(test);
            founder_team_reserve::start_phase1(&mut founderTeamGlobal, time_cap, &clock);
            tx_context::increment_epoch_timestamp(ctx(test), 1);
            return_shared(founderTeamGlobal);
        };

        // set swap whitelist
        next_tx(test, admin);
        {
            let swapGlobal = take_shared<swap::SwapGlobal>(test);
            let msg = x"be379359ac6e9d0fc0b867f147f248f1c2d9fc019a9a708adfcbe15fc3130c18";
            let sig = x"91EEC3C09428D1E3ECF7DDD723E71A6E7108293FD7B0EB6AE2C796A84D8DF3AE09D6119EE5FE9016BC14847C3AF69130B4CE06534EA1A5EBB13142BFCA0A430C";
            swap::white_list_backup(&mut swapGlobal, &sig, &msg, ctx(test));
            return_shared(swapGlobal);
            next_epoch(test, admin);
        };

        // set founder team whitelist
        next_tx(test, admin);
        {
            let type = 0;
            let founderTeamGlobal = take_shared<founder_team_reserve::FounderTeamGlobal>(test);
            let value = founder_team_reserve::get_total_shui_balance(&mut founderTeamGlobal);
            print(&string::utf8(b"reserve pool:"));
            print(&value);
            let whitelist = vector::empty();
            vector::push_back(&mut whitelist, test_user);
            founder_team_reserve::set_white_lists(&mut founderTeamGlobal, whitelist, type, ctx(test));
            return_shared(founderTeamGlobal);
            next_epoch(test, admin);
        };

        // reserve claim test
        clock::increment_for_testing(&mut clock, 1 * HOUR_IN_MS);
        next_tx(test, test_user);
        {
            let type = 0;
            let phase = 1;
            let founderTeamGlobal = take_shared<founder_team_reserve::FounderTeamGlobal>(test);
            let cliamed = founder_team_reserve::claim_reserve(&mut founderTeamGlobal, &clock, type, phase, ctx(test));
            print(&cliamed);
            return_shared(founderTeamGlobal);
        };

        // reserve claim test2
        clock::increment_for_testing(&mut clock, 30 * DAY_IN_MS + 1);
        next_tx(test, test_user);
        {
            let type = 0;
            let phase = 1;
            let founderTeamGlobal = take_shared<founder_team_reserve::FounderTeamGlobal>(test);
            let cliamed = founder_team_reserve::claim_reserve(&mut founderTeamGlobal, &clock, type, phase, ctx(test));
            print(&cliamed);
            return_shared(founderTeamGlobal);
        };

        clock::destroy_for_testing(clock);
        end(scenario);
    }
}