package minesweeper

import "core:fmt"
import "core:slice"
import random "core:math/rand"
import rl "vendor:raylib"

@(private="file")
MAX_FLOOD_TILES :: 100

@(private="file")
MINE_CHANCE :: 5

Minefield_Tile :: struct {
    index: i32,
    rect: rl.Rectangle,
    color: rl.Color,
    revealed: bool,
    flagged: bool,
    adjacent_mines: i32,
    has_mine: bool,
}

get_tile_xy :: proc(tile: Minefield_Tile) -> (i32,i32) {
    return i32(tile.rect.x), i32(tile.rect.y)
}

get_danger_color :: proc(tile: Minefield_Tile) -> rl.Color {
    switch tile.adjacent_mines {
        case 0..=1:
        return rl.BLUE
        case 2:
        return rl.GREEN
        case 3:
        return rl.RED
    }

    return rl.RED
}

Minefield :: struct {
    width: i32,
    height: i32,
    tiles: []Minefield_Tile,
    need_clearing: u32,
}

create_mine_field :: proc(offset: i32, width, height :i32) -> Minefield {
    grid_w := width / TILE_SIZE
    grid_h := height / TILE_SIZE
    num_tiles := grid_w * grid_h
    rand := random.create(0) 
    colors: [3]int = TILE_COLOR_PALLETE_HEX

    tiles := make([]Minefield_Tile, num_tiles)
    x_index: i32 = 0
    row: i32 = 0
    for tile_index in 0..<num_tiles {
        x_pos : = x_index * TILE_SIZE

        if x_pos >= width {
            x_index = 0
            x_pos = 0
            row += 1
        }

        x_index += 1
        y_pos: i32 = row * TILE_SIZE

        tile : Minefield_Tile
        tile.rect = rl.Rectangle{x=f32(x_pos + offset), y=f32(y_pos + offset ),width=TILE_SIZE,height=TILE_SIZE}
        random_color_index := random.int31_max(len(TILE_COLOR_PALLETE_HEX))
        tile.color = rl.GetColor(i32(colors[random_color_index]))
        tile.has_mine = false
        tile.index = tile_index
        tiles[tile_index] = tile
    }

    m: Minefield
    m.width = width
    m.height = height
    m.tiles = tiles
    m.need_clearing = 0
    return m
}

populate_mines :: proc(self: ^Minefield) {
    num_mines := 0
    for tile,idx in self.tiles {
        if tile.revealed {
            continue
        }

        if random.int31_max(MINE_CHANCE) == 1 {
            self.tiles[idx].has_mine = true
            num_mines += 1
        }
        else {
            self.need_clearing += 1
        }
    }
    
    fmt.println("Total tiles:", len(self.tiles))
    fmt.println("Number of mines:", num_mines)
    fmt.println("Tiles to clear:", self.need_clearing)
    update_neighbors(self)
} 

@(private="file")
get_tile_maybe :: proc(self: ^Minefield, x,y: i32) -> Maybe(Minefield_Tile) {
    if len(self.tiles) < 0 || x < 0 || y < 0 || x > self.width || y > self.height {
        return nil
    }

    for tile in self.tiles {
        other_x, other_y := get_tile_xy(tile)
        if x == other_x && y == other_y {
            return tile
        }
    }

    return nil
}

update_neighbors :: proc(self: ^Minefield) {
    for tile,i in self.tiles {
        self.tiles[i].adjacent_mines = 0
        for neighbor_maybe in get_neighbors(self, tile) {
            neighbor, ok := neighbor_maybe.?
            if !ok {
                continue;
            }

            if neighbor.has_mine {
                self.tiles[i].adjacent_mines += 1
            }
        }
    }
}

get_neighbors :: proc(self: ^Minefield, tile: Minefield_Tile, allocator := context.allocator) -> []Maybe(Minefield_Tile) {
    x, y := get_tile_xy(tile)

    neighbors := make([]Maybe(Minefield_Tile), 8, allocator) 
    neighbors[0] = get_tile_maybe(self,x - TILE_SIZE, y + TILE_SIZE)
    neighbors[1] = get_tile_maybe(self,x, y + TILE_SIZE)
    neighbors[2] = get_tile_maybe(self,x + TILE_SIZE, y + TILE_SIZE)
    neighbors[3] = get_tile_maybe(self,x + TILE_SIZE, y)
    neighbors[4] = get_tile_maybe(self,x + TILE_SIZE, y - TILE_SIZE)
    neighbors[5] = get_tile_maybe(self,x, y - TILE_SIZE)
    neighbors[6] = get_tile_maybe(self,x - TILE_SIZE, y - TILE_SIZE)
    neighbors[7] = get_tile_maybe(self,x - TILE_SIZE, y)
    return neighbors
}

reveal_tile :: proc(self: ^Minefield, tile: Minefield_Tile) {
    index := int(tile.index)
    if index < 0 || index > len(self.tiles) {
        return
    }

    if tile.revealed || tile.has_mine {
        return 
    }

    self.tiles[tile.index].revealed = true
    if self.need_clearing > 0 {
        self.need_clearing -= 1
    }
}

flood_reveal_from_tile :: proc (self: ^Minefield, tile: Minefield_Tile,) {
    x := i32(tile.rect.x)
    y := i32(tile.rect.y)

    queue : [dynamic]Minefield_Tile
    defer delete(queue)
    origin_tile, got_origin_tile := get_tile_maybe(self, x, y).?
    if !got_origin_tile {
        return
    }

    flood_revealed_tiles := 0
    append(&queue, origin_tile)

    flood: for {
        defer free_all(context.temp_allocator)
        if len(queue) == 0 {
            break
        }

        tile := pop(&queue)
        for n_maybe in get_neighbors(self, tile, context.temp_allocator)  {
            n, ok := n_maybe.?
            if !ok {
                continue
            }

            if flood_revealed_tiles >= MAX_FLOOD_TILES {
                break flood
            }

            if n.revealed || n.has_mine {
                continue
            }

            reveal_tile(self, n)
            flood_revealed_tiles += 1
            
            if n.adjacent_mines > 0 {
                continue
            }

            append(&queue, n)
        }
    }
}
