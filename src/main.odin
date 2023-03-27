package minesweeper

import "core:fmt"
import rl "vendor:raylib"

TILE_SIZE :: 32
OFF_WHITE :: rl.Color{240, 238, 233, 255}
TILE_COLOR_PALLETE_HEX :: [?]int{0x69B578, 0xD0DB97, 0x3A7D44}
BACKGROUND_COLOR_HEX :: 0x181D27
WINDOW_MARGIN :: TILE_SIZE
STARTING_FLAGS: u32 : 99

GameState :: enum {
	PRE_GAME,
	PLAYING,
	GAME_OVER, //Can mean either failure or victory.
}

main :: proc() {
	if ODIN_DEBUG {
		fmt.println("Running minesweeper in DEBUG mode...")
	}

	cfg_flags: rl.ConfigFlags
	cfg_flags = {rl.ConfigFlags.VSYNC_HINT}

	width: i32 = 512
	height: i32 = 512
	rl.SetConfigFlags(cfg_flags)
	rl.InitWindow(width + WINDOW_MARGIN * 2, height + WINDOW_MARGIN * 2, "Odin Minesweeper")

	{
		icon := rl.LoadImage("sprites/flag32x32.png")
		rl.ImageColorTint(&icon, OFF_WHITE)
		rl.SetWindowIcon(icon)
	}

	mine_sprite := rl.LoadTexture("sprites/mine32x32.png")
	flag_sprite := rl.LoadTexture("sprites/flag32x32.png")
	font_bold := rl.LoadFont("fonts/OpenSans-Bold.ttf")

	bg_color := rl.GetColor(BACKGROUND_COLOR_HEX)

	player_flags: u32 = STARTING_FLAGS
	mine_field := create_mine_field(WINDOW_MARGIN, width, height)
	game_state: GameState = GameState.PRE_GAME

	// Flag to reset the current game.
	wants_reset := false

	defer {
		rl.CloseWindow()
	}

	for !rl.WindowShouldClose() {
		mouse_pos := rl.GetMousePosition()
		left_click_rls := rl.IsMouseButtonReleased(rl.MouseButton.LEFT)
		right_click_rls := rl.IsMouseButtonReleased(rl.MouseButton.RIGHT)
		shift_left_click :=
			rl.IsMouseButtonDown(rl.MouseButton.LEFT) && rl.IsKeyDown(rl.KeyboardKey.LEFT_SHIFT)

		// TODO: The tile rects actually overlap by 1 tiny pixel.

		// Stops us from digging more than 1 tile per click.
		// Without this you can dig up a mine on your first ever click too.
		dug_tile_this_frame := false

		if rl.IsKeyReleased(rl.KeyboardKey.SPACE) {
			wants_reset = true
		}

		// Reset
		if wants_reset && game_state != .PRE_GAME {
			game_state = GameState.PRE_GAME
			mine_field = create_mine_field(WINDOW_MARGIN, width, height)
			player_flags = STARTING_FLAGS
			wants_reset = false
		}

		if rl.IsKeyReleased(rl.KeyboardKey.F12) {
			rl.TakeScreenshot("screenshot.png")
		}

		rl.BeginDrawing()
		rl.ClearBackground(bg_color)
		for tile, idx in mine_field.tiles {
			// Dig a tile
			if (left_click_rls || shift_left_click) &&
			   rl.CheckCollisionPointRec(mouse_pos, tile.rect) &&
			   !dug_tile_this_frame {
				#partial switch game_state {
				case .PRE_GAME:
					{
						reveal_tile(&mine_field, tile)
						populate_mines(&mine_field)
						flood_reveal_from_tile(&mine_field, tile)
						game_state = .PLAYING
						dug_tile_this_frame = true
					}
				case .PLAYING:
					{
						if !tile.flagged {
							reveal_tile(&mine_field, tile)
							dug_tile_this_frame = true
						}

						if tile.has_mine && !tile.flagged {
							game_state = GameState.GAME_OVER
						} else if tile.adjacent_mines <= 0 {
							flood_reveal_from_tile(&mine_field, tile)
							dug_tile_this_frame = true
						}
					}
				case .GAME_OVER:
					{
					}
				}
			}

			// Flag a tile or reset the game if the game is over.
			if right_click_rls {
				#partial switch game_state {
				case .PLAYING:
					{
						if !tile.revealed && rl.CheckCollisionPointRec(mouse_pos, tile.rect) {
							flag_result := flag_tile(&mine_field, tile)

							if !flag_result {
								player_flags += 1
							} else {
								player_flags -= 1
							}
						}
					}

				// Handle reset
				case .GAME_OVER:
					{
						wants_reset = true
					}
				}

			}

			if game_state == GameState.PLAYING && mine_field.need_clearing <= 0 {
				game_state = GameState.GAME_OVER
			}

			tile_draw_color := tile.revealed ? bg_color : tile.color
			rl.DrawRectangleRounded(shrink_rect(tile.rect, 2), 0.3, 4, tile_draw_color)

			if !tile.has_mine && tile.revealed && tile.adjacent_mines > 0 {
				rl.DrawTextEx(
					font_bold,
					rl.TextFormat("%d", tile.adjacent_mines),
					rl.Vector2{tile.rect.x + TILE_SIZE / 4, tile.rect.y + TILE_SIZE / 4},
					24,
					0,
					get_danger_color(tile),
				)
			}

			if (tile.has_mine && game_state == GameState.GAME_OVER) ||
			   (tile.has_mine && ODIN_DEBUG) {
				rl.DrawTexture(mine_sprite, i32(tile.rect.x), i32(tile.rect.y), rl.RED)
			}

			if tile.flagged {
				rl.DrawTexture(flag_sprite, i32(tile.rect.x), i32(tile.rect.y), OFF_WHITE)
			}
		}

		title :: "Minesweeper"
		title_width := rl.MeasureTextEx(font_bold, title, 24, 0).x / 2
		rl.DrawTextEx(
			font_bold,
			title,
			rl.Vector2{f32(rl.GetScreenWidth() / 2) - title_width, 1},
			24,
			0,
			OFF_WHITE,
		)

		if game_state == GameState.GAME_OVER {

		}

		rl.EndDrawing()
	}
}

shrink_rect :: proc(rect: rl.Rectangle, amount: f32) -> rl.Rectangle {
	return rl.Rectangle{rect.x, rect.y + amount, rect.width - amount, rect.height - amount}
}
