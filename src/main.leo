// The 'aleo_bingo' program.
program aleo_bingo.aleo {

    // BingoPublicInfo 是游戏的公开信息
    // BingoPublicInfo is the public information about the game
    struct BingoPublicInfo {
        max_rounds_of_winners: u64, // maximum winners in a game 游戏中的最大赢家
        prize_pool: u64, // prize amount of the game 游戏奖金额
    }

    // SimpleBingo 是游戏在链上的记录
    // SimpleBingo is the record of the game on the chain
    record SimpleBingo {
        private owner: address, // creator of the game 游戏创建者
        public id: field, // id of the game 游戏 ID
        public public_info: BingoPublicInfo,
    }

    struct Row {
        c1: u64, // 柱子 column B
        c2: u64, // 柱子 column I
        c3: u64, // 柱子 column N
        c4: u64, // 柱子 column G
        c5: u64, // 柱子 column O
        c1_hit: bool, // 柱子 column B, 如果它是一击 if it was a hit
        c2_hit: bool, // 柱子 column I, 如果它是一击 if it was a hit
        c3_hit: bool, // 柱子 column N, 如果它是一击 if it was a hit
        c4_hit: bool, // 柱子 column G, 如果它是一击 if it was a hit
        c5_hit: bool, // 柱子 column O, 如果它是一击 if it was a hit
    }

    // Board 是游戏卡的网格
    // Board is the Game Card's Grid
    struct Board {
        r1: Row, // row 1 of BINGO, BINGO 第一行
        r2: Row, // row 2 of BINGO, BINGO 第二行
        r3: Row, // row 3 of BINGO, BINGO 第三行
        r4: Row, // row 4 of BINGO, BINGO 第四行
        r5: Row, // row 5 of BINGO, BINGO 第五行
    }

    // BingoGameCard 是玩家的卡片
    // BingoGameCard is the player's card
    record BingoGameCard {
        public game_id: field, // game's id 游戏ID
        public id: field, // card's ID 卡号
        private owner: address, // card's owner 卡的所有者
        private winning_card: bool, // if it is a winning card 如果是中奖牌
        private win_amount: u64, // winning amount (not used currently) 中奖金额（暂未使用）
        private content: Board, // the card's grid content 卡片的网格内容
    }

    // 计算每个宾果游戏的玩家数量。游戏 ID => 计数
    // Count number of players per Bingo. gameID => count
    mapping games: field => u64;

    // 创建的游戏 gameID => bool
    // games that are created gameID => bool
    mapping games_created: field => bool;

    // 开始的游戏 gameID => bool
    // games that started gameID => bool
    mapping games_started: field => bool;

    // 完成的游戏 gameID => bool
    // games that completed gameID => bool
    mapping games_completed: field => bool;

    // playerID => gameID，一个玩家一次只能玩一个游戏
    // playerID => gameID, one player can only play 1 game at a time
    mapping players_to_game: address => field;

    // 游戏卡 ID => 游戏 ID
    // gameCard ID => gameID
    mapping gamecards: field => field;

    // gamesID => 获胜者的回合数
    // gamesID => round number count with winners
    mapping games_rounds_of_winners: field => u64;

    // 26 bytes| 4 bytes
    // 游戏ID｜游戏回合=> u64
    // gamesID｜round => u64
    mapping column_game_round: field => u8;

    // 26 bytes| 4bytes
    // 游戏 ID｜round => u64
    // game ID｜round => u64
    mapping game_round_value: field => u64;

    // 26 bytes
    // 游戏 ID => u64
    // game ID => u64
    mapping game_round_number: field => u64;

    // create_game 将创建一个 SimpleBingo 记录
    // create_game will create a SimpleBingo record
    transition create_game(
            public max_rounds_of_winners: u64, 
            rounds_of_winners: u64,
            prize_pool: u64,
            game_id: field,
        ) -> SimpleBingo {

        // public information 公共信息
        let new_bingo_info: BingoPublicInfo = BingoPublicInfo {
            max_rounds_of_winners: max_rounds_of_winners,
            prize_pool: prize_pool,
        };

        // create game 创建游戏
        let bingo_game: SimpleBingo = SimpleBingo {
            owner: self.caller,
            id: game_id,
            public_info: new_bingo_info,
        };

        return bingo_game then finalize(game_id);
    }

    // finalize-create_game 将在运行 create_game 转换函数后运行所需的检查。如果失败，则转换未完成
    // finalize-create_game willrun the required check's after the create_game transition function was ran. If this fails the transition is not completed
    finalize create_game(game_id: field) {
        // check the game was not created before 检查之前未创建游戏
        assert(!Mapping::get(games_created, game_id));

        // set games_created map to true 将 games_created 地图设置为 true
        Mapping::set(games_created, game_id, true);
    }
    // join_game 将为相应的游戏 ID 创建玩家的游戏卡
    // join_game will create a player's game card for the respective game id
    transition join_game(id: field, game_id: field, board: Board) -> BingoGameCard {

        // create game card 创建游戏卡
        let game_Card: BingoGameCard = BingoGameCard {
            game_id: game_id,
            id: id,
            owner: self.caller,
            winning_card: false,
            win_amount: 0u64,
            content: board,
        };

        return game_Card then finalize(self.caller, game_id, id);
    }

    // finalize-join_game 将增加游戏的玩家数量
    // finalize-join_game will increment the player count for the game
    finalize join_game(player: address, game_id: field, id: field) {
        // check the game has not started 检查游戏还没有开始
        assert(!Mapping::get(games_started, game_id));

        // check the game has not completed 检查游戏还没有完成
        assert(!Mapping::get(games_completed, game_id));

        // TODO check unique card id, this is currently not available 检查唯一的卡 ID, 这目前不可用
        // assert(""!=Mapping::get(gamecards, id));

        let current_game_id: field = Mapping::get(players_to_game, self.caller);

        // should also check that his previous game has ended 还应该检查他之前的游戏是否已经结束
        if (game_id != current_game_id) {
            // set player to be in new game id 将玩家设置为新游戏ID
            Mapping::set(players_to_game, self.caller, game_id);
        }

        Mapping::set(games, game_id, Mapping::get(games, game_id) + 1u64);

        // TODO should also check that the columns in each board do not have the same number 还应检查每个板中的列是否具有相同的编号
    }

    // start_game 将开始游戏并为 games_started 映射创建键值对
    // start_game will start the game and create the key value pair for games_started mapping
    transition start_game (game: SimpleBingo) -> SimpleBingo {
        // check game created is indeed the owner 检查创建的游戏确实是所有者
        assert(game.owner == self.caller);

        return SimpleBingo {
            owner: self.caller,
            id: game.id,
            public_info: game.public_info,
        } then finalize(game.id);
    }

    finalize start_game(gameId: field) {
        // check the game has not started 检查游戏还没有开始
        assert(!Mapping::get(games_started, gameId));
        
        Mapping::set(games_started, gameId, true);
    }

    // next_round 将开始游戏并为 games_started 映射创建键值对
    // next_round will start the game and create the key value pair for games_started mapping
    transition next_round(game: SimpleBingo, column: u8, number: u64, game_round_col: field, game_round_target_value: field) -> SimpleBingo {
        // check that only owner can update game state 检查是否只有所有者可以更新游戏状态
        assert(game.owner == self.caller);
        // TODO check for proof of randomness 检查随机性证明

        // new public information 新的公开信息
        let new_bingo_info: BingoPublicInfo = BingoPublicInfo {
            max_rounds_of_winners: game.public_info.max_rounds_of_winners,
            prize_pool: game.public_info.prize_pool,
        };

        // new bingo state 新宾果状态
        let new_bingo_state: SimpleBingo = SimpleBingo {
            owner: self.caller,
            id: game.id,
            public_info: new_bingo_info,
        };

        return new_bingo_state then finalize(game.id, game_round_col, game_round_target_value, column, number);
    }

    finalize next_round (gameId: field, game_round_col: field, game_round_target_value: field, column: u8, number: u64 ) {
        // check game started 检查游戏开始
        assert(Mapping::get(games_started, gameId));
        // check game not complete 检查游戏未完成
        assert(!Mapping::get(games_completed, gameId));

        // set new round number 设置新的轮数
        let new_round_number: u64 = Mapping::get(game_round_number, gameId) + 1u64;
        Mapping::set(game_round_number, gameId, new_round_number);
        // TODO Because there's no way I can type cast now, I cannot compare the inputs 因为我现在无法输入 cast，所以我无法比较输入
        // For now we will just take it as it is 现在我们将按原样接受它

        // TODO check that game round values are unique, this is currently not available, 检查游戏回合值是否唯一，目前不可用
        // assert(!Mapping::get(column_game_round, game_round_col));
        // assert(!Mapping::get(game_round_value, game_round_target_value));

        Mapping::set(column_game_round, game_round_col, column);
        Mapping::set(game_round_value, game_round_target_value, number);
    }

    // check_for_win 是检查玩家卡片的网格内容是否赢得游戏的函数。由 check_card 转换函数使用
    // check_for_win is a function to check if the player card's grid content has won the game. used by check_card transition function
    function check_for_win(updated_card: Board) -> bool {
        let count: u8 = 0u8;

        if (updated_card.r1.c1_hit && updated_card.r1.c2_hit && updated_card.r1.c3_hit && updated_card.r1.c4_hit && updated_card.r1.c5_hit) {
            count = count + 1u8;
        } else if (updated_card.r2.c1_hit && updated_card.r2.c2_hit && updated_card.r2.c3_hit && updated_card.r2.c4_hit && updated_card.r2.c5_hit) {
            count = count + 1u8;
        } else if (updated_card.r3.c1_hit && updated_card.r3.c2_hit && updated_card.r3.c3_hit && updated_card.r3.c4_hit && updated_card.r3.c5_hit) {
            count = count + 1u8;
        } else if (updated_card.r4.c1_hit && updated_card.r4.c2_hit && updated_card.r4.c3_hit && updated_card.r4.c4_hit && updated_card.r4.c5_hit) {
            count = count + 1u8;
        } else if (updated_card.r5.c1_hit && updated_card.r5.c2_hit && updated_card.r5.c3_hit && updated_card.r5.c4_hit && updated_card.r5.c5_hit) {
            count = count + 1u8;
        } else if (updated_card.r1.c1_hit && updated_card.r2.c1_hit && updated_card.r3.c1_hit && updated_card.r4.c1_hit && updated_card.r5.c1_hit) {
            count = count + 1u8;
        } else if (updated_card.r1.c2_hit && updated_card.r2.c2_hit && updated_card.r3.c2_hit && updated_card.r4.c2_hit && updated_card.r5.c2_hit) {
            count = count + 1u8;
        } else if (updated_card.r1.c3_hit && updated_card.r2.c3_hit && updated_card.r3.c3_hit && updated_card.r4.c3_hit && updated_card.r5.c3_hit) {
            count = count + 1u8;
        } else if (updated_card.r1.c4_hit && updated_card.r2.c4_hit && updated_card.r3.c4_hit && updated_card.r4.c4_hit && updated_card.r5.c4_hit) {
            count = count + 1u8;
        } else if (updated_card.r1.c5_hit && updated_card.r2.c5_hit && updated_card.r3.c5_hit && updated_card.r4.c5_hit && updated_card.r5.c5_hit) {
            count = count + 1u8;
        } else if (updated_card.r1.c1_hit && updated_card.r2.c2_hit && updated_card.r3.c3_hit && updated_card.r4.c4_hit && updated_card.r5.c5_hit) {
            count = count + 1u8;
        } else if (updated_card.r1.c5_hit && updated_card.r2.c4_hit && updated_card.r3.c3_hit && updated_card.r4.c2_hit && updated_card.r5.c1_hit) {
            count = count + 1u8;
        }
        return count >= 3u8;
    }

    // check_card 将检查玩家的游戏卡，如果玩家赢了则更新 games_rounds_of_winners 并更新游戏卡的状态。
    // check_card will check the player's game card, update games_rounds_of_winners if the player won and update game card's state.
    transition check_card(game_card: BingoGameCard, target_col: u8, target_value: u64) -> BingoGameCard {
        let r1c1_hit: bool = game_card.content.r1.c1_hit;
        let r2c1_hit: bool = game_card.content.r2.c1_hit;
        let r3c1_hit: bool = game_card.content.r3.c1_hit;
        let r4c1_hit: bool = game_card.content.r4.c1_hit;
        let r5c1_hit: bool = game_card.content.r5.c1_hit;

        let r1c2_hit: bool = game_card.content.r1.c2_hit;
        let r2c2_hit: bool = game_card.content.r2.c2_hit;
        let r3c2_hit: bool = game_card.content.r3.c2_hit;
        let r4c2_hit: bool = game_card.content.r4.c2_hit;
        let r5c2_hit: bool = game_card.content.r5.c2_hit;

        let r1c3_hit: bool = game_card.content.r1.c3_hit;
        let r2c3_hit: bool = game_card.content.r2.c3_hit;
        let r3c3_hit: bool = game_card.content.r3.c3_hit;
        let r4c3_hit: bool = game_card.content.r4.c3_hit;
        let r5c3_hit: bool = game_card.content.r5.c3_hit;

        let r1c4_hit: bool = game_card.content.r1.c4_hit;
        let r2c4_hit: bool = game_card.content.r2.c4_hit;
        let r3c4_hit: bool = game_card.content.r3.c4_hit;
        let r4c4_hit: bool = game_card.content.r4.c4_hit;
        let r5c4_hit: bool = game_card.content.r5.c4_hit;

        let r1c5_hit: bool = game_card.content.r1.c5_hit;
        let r2c5_hit: bool = game_card.content.r2.c5_hit;
        let r3c5_hit: bool = game_card.content.r3.c5_hit;
        let r4c5_hit: bool = game_card.content.r4.c5_hit;
        let r5c5_hit: bool = game_card.content.r5.c5_hit;

        if (target_col == 1u8) {
            let r1c1: u64 = game_card.content.r1.c1;
            let r2c1: u64 = game_card.content.r2.c1;
            let r3c1: u64 = game_card.content.r3.c1;
            let r4c1: u64 = game_card.content.r4.c1;
            let r5c1: u64 = game_card.content.r5.c1;

            if (r1c1 == target_value) {
                r1c1_hit = true;
            } else if (r2c1 == target_value) {
                r2c1_hit = true;
            } else if (r3c1 == target_value) {
                r3c1_hit = true;
            } else if (r4c1 == target_value) {
                r4c1_hit = true;
            } else if (r5c1 == target_value) {
                r5c1_hit = true;
            }
        } else if (target_col == 2u8) {
            let r1c2: u64 = game_card.content.r1.c2;
            let r2c2: u64 = game_card.content.r2.c2;
            let r3c2: u64 = game_card.content.r3.c2;
            let r4c2: u64 = game_card.content.r4.c2;
            let r5c2: u64 = game_card.content.r5.c2;

            if (r1c2 == target_value) {
                r1c2_hit = true;
            } else if (r2c2 == target_value) {
                r2c2_hit = true;
            } else if (r3c2 == target_value) {
                r3c2_hit = true;
            } else if (r4c2 == target_value) {
                r4c2_hit = true;
            } else if (r5c2 == target_value) {
                r5c2_hit = true;
            }

        } else if (target_col == 3u8) {
            let r1c3: u64 = game_card.content.r1.c3;
            let r2c3: u64 = game_card.content.r2.c3;
            let r3c3: u64 = game_card.content.r3.c3;
            let r4c3: u64 = game_card.content.r4.c3;
            let r5c3: u64 = game_card.content.r5.c3;

            if (r1c3 == target_value) {
                r1c3_hit = true;
            } else if (r2c3 == target_value) {
                r2c3_hit = true;
            } else if (r3c3 == target_value) {
                r3c3_hit = true;
            } else if (r4c3 == target_value) {
                r4c3_hit = true;
            } else if (r5c3 == target_value) {
                r5c3_hit = true;
            }
        } else if (target_col == 4u8) {
            let r1c4: u64 = game_card.content.r1.c4;
            let r2c4: u64 = game_card.content.r2.c4;
            let r3c4: u64 = game_card.content.r3.c4;
            let r4c4: u64 = game_card.content.r4.c4;
            let r5c4: u64 = game_card.content.r5.c4;

            if (r1c4 == target_value) {
                r1c4_hit = true;
            } else if (r2c4 == target_value) {
                r2c4_hit = true;
            } else if (r3c4 == target_value) {
                r3c4_hit = true;
            } else if (r4c4 == target_value) {
                r4c4_hit = true;
            } else if (r5c4 == target_value) {
                r5c4_hit = true;
            }
        } else if (target_col == 5u8) {
            let r1c5: u64 = game_card.content.r1.c5;
            let r2c5: u64 = game_card.content.r2.c5;
            let r3c5: u64 = game_card.content.r3.c5;
            let r4c5: u64 = game_card.content.r4.c5;
            let r5c5: u64 = game_card.content.r5.c5;

            if (r1c5 == target_value) {
                r1c5_hit = true;
            } else if (r2c5 == target_value) {
                r2c5_hit = true;
            } else if (r3c5 == target_value) {
                r3c5_hit = true;
            } else if (r4c5 == target_value) {
                r4c5_hit = true;
            } else if (r5c5 == target_value) {
                r5c5_hit = true;
            }
        }

        let updated_card: Board = Board {
            r1: Row {  c1: game_card.content.r1.c1, c2: game_card.content.r1.c2, c3: game_card.content.r1.c3, c4: game_card.content.r1.c4, c5: game_card.content.r1.c5, c1_hit: r1c1_hit, c2_hit: r1c2_hit, c3_hit: r1c3_hit, c4_hit: r1c4_hit, c5_hit: r1c5_hit },
            r2: Row {  c1: game_card.content.r1.c1, c2: game_card.content.r1.c2, c3: game_card.content.r1.c3, c4: game_card.content.r1.c4, c5: game_card.content.r1.c5, c1_hit: r2c1_hit, c2_hit: r2c2_hit, c3_hit: r2c3_hit, c4_hit: r2c4_hit, c5_hit: r2c5_hit },
            r3: Row {  c1: game_card.content.r1.c1, c2: game_card.content.r1.c2, c3: game_card.content.r1.c3, c4: game_card.content.r1.c4, c5: game_card.content.r1.c5, c1_hit: r3c1_hit, c2_hit: r3c2_hit, c3_hit: r3c3_hit, c4_hit: r3c4_hit, c5_hit: r3c5_hit },
            r4: Row {  c1: game_card.content.r1.c1, c2: game_card.content.r1.c2, c3: game_card.content.r1.c3, c4: game_card.content.r1.c4, c5: game_card.content.r1.c5, c1_hit: r4c1_hit, c2_hit: r4c2_hit, c3_hit: r4c3_hit, c4_hit: r4c4_hit, c5_hit: r4c5_hit },
            r5: Row {  c1: game_card.content.r1.c1, c2: game_card.content.r1.c2, c3: game_card.content.r1.c3, c4: game_card.content.r1.c4, c5: game_card.content.r1.c5, c1_hit: r5c1_hit, c2_hit: r5c2_hit, c3_hit: r5c3_hit, c4_hit: r5c4_hit, c5_hit: r5c5_hit },
        };

        // check if player won 检查玩家是否赢了
        let player_won: bool = check_for_win(updated_card);

        let new_game_card_state: BingoGameCard = BingoGameCard {
            game_id: game_card.game_id,
            id: game_card.id,
            owner: self.caller,
            winning_card: player_won,
            win_amount: 0u64,
            content: updated_card,
        };

        return new_game_card_state then finalize(player_won, game_card.winning_card, game_card.game_id);
    }

    finalize check_card(player_won: bool, game_card_winning_card: bool, gameId: field) {
        // If his card was not marked as won and he won this round 如果他的牌没有被标记为赢了并且他赢了这一局
        if (player_won && !game_card_winning_card) {
            let number_of_winners: u64 = Mapping::get_or_init(games_rounds_of_winners, gameId, 0u64);
            Mapping::set(games_rounds_of_winners, gameId, number_of_winners + 1u64);
        }
    }

    // check_winners 将被游戏所有者调用以查看游戏是否结束。
    // check_winners will be called by the game's owner to see if the game has ended.
    transition check_winners(game: SimpleBingo) {
        // check that they are the owner of the game 检查他们是否是游戏的所有者
        assert(game.owner == self.caller);

        return then finalize(game.id, game.public_info.max_rounds_of_winners);
    }

    finalize check_winners(gameId: field, max_rounds_of_winners: u64) {
        let number_of_winners: u64 = Mapping::get(games_rounds_of_winners, gameId);

        // if it hits the number of winners, game ends 如果达到获胜者的数量，游戏结束
        if (number_of_winners >= max_rounds_of_winners) {
            Mapping::set(games_completed, gameId, true);
        }
    }

}
