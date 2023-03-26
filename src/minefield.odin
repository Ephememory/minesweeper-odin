package minesweeper

import "core:fmt"
import "core:slice"
import random "core:math/rand"
import rl "vendor:raylib"

@(private="file")
MAX_FLOOD_TILES :: 100

@(private="file")
MINE_CHANCE :: 5

Tile_Coords :: struct {
    x: i32,
    y: i32,
}

tilecoords_equal :: proc(self, coords: Tile_Coords) -> bool {
    return self.x == coords.x && self.y == coords.y
}

Minefield_Tile :: struct {
    index: i32,
    coords: Tile_Coords,
    rect: rl.Rectangle,
    color: rl.Color,
    revealed: bool,
    flagged: bool,
    adjacent_mines: i32,
    has_mine: bool,
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
    size: rl.Vector2,
    tiles: []Minefield_Tile,
    need_clearing: u32,
}

create_mine_field :: proc(offset: i32, width, height :i32) -> Minefield {
    num_tiles := (width / TILE_SIZE) * (height / TILE_SIZE)
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
        tile.coords = Tile_Coords{x=x_pos,y=y_pos}
        tiles[tile_index] = tile
    }

    m: Minefield
    m.size = rl.Vector2{f32(width), f32(height)}
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
    coords := Tile_Coords{x=x,y=y}
    x:= f32(coords.x)
    y:= f32(coords.y)

    if len(self.tiles) < 0 || x < 0 || y < 0 || x > self.size.x || y > self.size.y {
        return nil
    }

    for tile in self.tiles {
        if tilecoords_equal(tile.coords, coords) {
            return tile
        }
    }

    return nil
}

update_neighbors :: proc(self: ^Minefield) {
    for tile in &self.tiles {
        using tile
        tile.adjacent_mines = 0
        for neighbor_maybe in get_neighbors(self, tile) {
            neighbor, ok := neighbor_maybe.?
            if !ok {
                continue;
            }

            if neighbor.has_mine {
                tile.adjacent_mines += 1
            }
        }
    }
}

get_neighbors :: proc(self: ^Minefield, tile: Minefield_Tile) -> []Maybe(Minefield_Tile) {
    x := tile.coords.x
    y := tile.coords.y

    neighbors := []Maybe(Minefield_Tile){
        get_tile_maybe(self,x - TILE_SIZE, y + TILE_SIZE),
        get_tile_maybe(self,x, y + TILE_SIZE),
        get_tile_maybe(self,x + TILE_SIZE, y + TILE_SIZE),
        get_tile_maybe(self,x + TILE_SIZE, y),
        get_tile_maybe(self,x + TILE_SIZE, y - TILE_SIZE),
        get_tile_maybe(self,x, y - TILE_SIZE),
        get_tile_maybe(self,x - TILE_SIZE, y - TILE_SIZE),
        get_tile_maybe(self,x - TILE_SIZE, y),
    }

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

    // Uncommenting these lines leads to random tiles
    // being revealed.

    // if self.need_clearing > 0 {
    //     self.need_clearing -= 1
    // }
}

flood_reveal_from_tile :: proc (self: ^Minefield, tile: Minefield_Tile) {
    x := i32(tile.rect.x)
    y := i32(tile.rect.y)

    queue : [dynamic]Minefield_Tile
    origin_tile, got_origin_tile := get_tile_maybe(self, x, y).?
    if !got_origin_tile {
        return
    }

    flood_revealed_tiles := 0
    append(&queue, origin_tile)

    flood: for {
        if len(queue) == 0 {
            break
        }

        tile := pop(&queue)
        for n_maybe in get_neighbors(self, tile) {
            n, ok := n_maybe.?
            if !ok {
                continue
            }

            if flood_revealed_tiles >= MAX_FLOOD_TILES {
                break flood
            }

            if n.has_mine || n.revealed {
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

    delete(queue)
}
