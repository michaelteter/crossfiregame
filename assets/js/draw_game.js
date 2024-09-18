const Color = {
  red: "rgb(248, 113, 113)",
  dkRed: "rgb(198, 90, 90)",
  ltRed: "rgb(255, 136, 136)",
  blue: "rgb(96, 165, 250)",
  dkBlue: "rgb(77, 132, 200)",
  ltBlue: "rgb(115, 198, 255)",
  green: "rgb(74, 222, 128)",
  dkGreen: "rgb(59, 178, 102)",
  ltGreen: "rgb(89, 255, 154)",
  yellow: "rgb(250, 204, 21)",
  dkYellow: "rgb(200, 163, 17)",
  ltYellow: "rgb(255, 245, 25)",
};

const PlayerColor = {
  1: {
    normal: Color.red,
    light: Color.ltRed,
    dark: Color.dkRed,
  },
  2: {
    normal: Color.blue,
    light: Color.ltBlue,
    dark: Color.dkBlue,
  },
  3: {
    normal: Color.green,
    light: Color.ltGreen,
    dark: Color.dkGreen,
  },
  4: {
    normal: Color.yellow,
    light: Color.ltYellow,
    dark: Color.dkYellow,
  },
};

const PlayerArrow = {
  1: { 1: "↑", 2: "↓", 3: "←", 4: "→" },
  2: { 1: "↓", 2: "↑", 3: "→", 4: "←" },
  3: { 1: "→", 2: "←", 3: "↑", 4: "↓" },
  4: { 1: "←", 2: "→", 3: "↓", 4: "↑" },
};

// From the perspective of the player, what other player is on a given side?
const PlayerOnSide = {
  1: { top: 2, bottom: 1, left: 4, right: 3 },
  2: { top: 1, bottom: 2, left: 3, right: 4 },
  3: { top: 4, bottom: 3, left: 1, right: 2 },
  4: { top: 3, bottom: 4, left: 2, right: 1 },
};

// From the perspective of the player, what side is a given other player on?
const SideOfOtherPlayer = {
  1: { 1: "bottom", 2: "top", 3: "right", 4: "left" },
  2: { 1: "top", 2: "bottom", 3: "left", 4: "right" },
  3: { 1: "left", 2: "right", 3: "bottom", 4: "top" },
  4: { 1: "right", 2: "left", 3: "top", 4: "bottom" },
};

let DrawGame = {
  mounted() {
    this.playerNum = parseInt(this.el.dataset.playerNum, 10);

    this.canvas = document.getElementById("game-board");
    this.context = this.canvas.getContext("2d");
    this.context.imageSmoothingEnabled = false;

    this.lastHoverSlot = null;

    this.canvas.addEventListener("mousemove", this.handleMouseMove.bind(this));
    this.canvas.addEventListener("click", this.handleCanvasClick.bind(this));

    this.computeLayoutProperties();
    this.computeShotSlotBoundaries();

    this.drawGame();
  },

  updated() {
    this.drawGame();
  },

  isPlaying() {
    return this.el.dataset.gameStatus === "playing";
  },

  computeShotSlotBoundaries() {
    this.slotBoundaries = {};

    for (let i = 0; i < this.nSlots; i += 1) {
      const xMin = this.xBottomPlayer + i * this.wSection + 1;
      const yMin = this.yBottomPlayer + 1;
      const xMax = xMin + this.wSection - 1;
      const yMax = this.yBottomPlayer + this.hSection - 1;
      this.slotBoundaries[i + 1] = { xMin, xMax, yMin, yMax };
    }
  },

  handleMouseMove(event) {
    if (!this.isPlaying()) return;

    const pos = this.getMousePosition(event);
    this.reactToMousePosition(pos);
  },

  getMousePosition(event) {
    const rect = this.canvas.getBoundingClientRect();
    return {
      xPointer: event.clientX - rect.left,
      yPointer: event.clientY - rect.top,
    };
  },

  slotIsHoldingAShot(shotPlayer, slot) {
    const translatedSlot = this.translateShotSlot(shotPlayer, parseInt(slot));

    // TODO: why is slot sometimes a string?
    const holdingShots = this.parseJsonData(this.el.dataset.holdingShots);

    for (const [playerNum, holdingSlot] of holdingShots) {
      if (playerNum === shotPlayer && holdingSlot === parseInt(translatedSlot)) {
        return true;
      }
    }

    return false;
  },

  reactToMousePosition({ xPointer, yPointer }) {
    // is the mouse over a slot?

    const ctx = this.context;

    if (
      xPointer < this.xBottomPlayer ||
      xPointer > this.xBottomPlayer + this.nSlots * this.wSection ||
      yPointer < this.yBottomPlayer ||
      yPointer > this.yBottomPlayer + this.hSection
    ) {
      // Pointer is not over any of the player's slots.
      // Redraw the last hover slot as normal if it exists.
      if (this.lastHoverSlot) {
        this.drawShotSlot("bottom", this.playerNum, this.lastHoverSlot);
        this.lastHoverSlot = null;
      }
      return;
    }

    let inSlot = null;

    for (const [slot, { xMin, xMax, yMin, yMax }] of Object.entries(this.slotBoundaries)) {
      if (xPointer > xMin && xPointer < xMax && yPointer > yMin && yPointer < yMax) {
        inSlot = slot;
        break;
      }
    }

    // We now know which slot, if any, the pointer is over.
    // If we are hovering over a the same slot as the last time, do nothing.
    // If we are hovering over no slot, then we're done.
    if (inSlot == this.lastHoverSlot) return;

    if (this.lastHoverSlot) {
      // Reset (redraw) the lastHoverSlot since we are elsewhere now.
      this.drawShotSlot("bottom", this.playerNum, this.lastHoverSlot);
    }

    if (inSlot) {
      // Update (redraw) the current slot since we are hovering over it.
      this.drawShotSlot("bottom", this.playerNum, inSlot, true);
    }

    // Remember this slot for later.
    this.lastHoverSlot = inSlot;
  },

  shotSlotOrigin(side, slotIndex) {
    // Given a side of the board and slot position, determine the (x,y) coordinates
    // of the top-left corner of the slot.
    switch (side) {
      case "top":
        xMin = this.xTopPlayer + (slotIndex - 1) * this.wSection;
        yMin = this.yTopPlayer;
        break;
      case "bottom":
        xMin = this.xBottomPlayer + (slotIndex - 1) * this.wSection;
        yMin = this.yBottomPlayer;
        break;
      case "left":
        xMin = this.xLeftPlayer;
        yMin = this.yLeftPlayer + (slotIndex - 1) * this.hSection;
        break;
      case "right":
        xMin = this.xRightPlayer;
        yMin = this.yRightPlayer + (slotIndex - 1) * this.hSection;
        break;
      default:
        throw new Error("Invalid side");
    }

    return [xMin, yMin];
  },

  drawShotSlot(side, playerNum, slotIndex, isHover = false) {
    // Determine the color based on the following criteria:
    //   Player number
    //     shot holding
    //     mouse hover
    const isHolding = this.slotIsHoldingAShot(playerNum, slotIndex);

    let color;
    if (isHolding) {
      color = PlayerColor[playerNum].dark;
    } else {
      if (isHover) {
        color = PlayerColor[playerNum].light;
      } else {
        color = PlayerColor[playerNum].normal;
      }
    }

    const symbol = isHolding ? "⦿" : null;

    const [x, y] = this.shotSlotOrigin(side, slotIndex);

    const ctx = this.context;
    ctx.fillStyle = color;
    ctx.fillRect(x + 1, y + 1, this.wSection - 2, this.hSection - 2);

    if (symbol) {
      this.drawCenteredText(ctx, x, y, x + this.wSection, y + this.hSection, symbol);
    }
  },

  handleCanvasClick(event) {
    if (!this.isPlaying()) return;

    // Calculate the click position relative to the canvas
    const rect = this.canvas.getBoundingClientRect();
    const x = event.clientX - rect.left;
    const y = event.clientY - rect.top;

    if (y <= this.yBottomPlayer || y >= this.yBottomPlayer + this.hSection) {
      // Click position was above or below the bottom slots, so ignore it.
      return;
    }

    if (x > this.xBottomPlayer && x < this.xBottomPlayer + this.nSlots * this.wSection) {
      // Click position was horizontally between the bottom slot boundaries.
      // And from the previous check, we know it is within the vertical boundaries.

      // Determine which slot was clicked, and send a "shoot" event to the server.
      const slotIndex = Math.floor((x - this.xBottomPlayer) / this.wSection);
      this.pushEvent("shoot", { slot: slotIndex + 1 });
    }
  },

  parseJsonData(jsonData) {
    try {
      return JSON.parse(jsonData);
    } catch (e) {
      console.error("♐︎♐︎♐︎♐︎♐︎ Failed to parse game state:", e);
      return {}; // Return an empty state on error
    }
  },

  computeLayoutProperties() {
    this.wCanvas = this.canvas.width;
    this.hCanvas = this.canvas.height;

    this.hPadCanvas = 2;
    this.vPadCanvas = 2;

    this.nGridRows = 8;
    this.nGridCols = this.nGridRows;
    this.nSlots = this.nGridRows;

    this.wSection = Math.floor((this.wCanvas - 2 * this.hPadCanvas) / 12);
    this.wBlock = this.wSection;
    this.hSection = Math.floor((this.hCanvas - 2 * this.vPadCanvas) / 12);
    this.hBlock = this.hSection;

    this.vMarginGrid = Math.floor((this.hSection * 2) / 3);
    this.hMarginGrid = Math.floor((this.wSection * 2) / 3);

    this.xGrid = Math.floor(this.wCanvas / 2) - 4 * this.wSection;
    this.yGrid = Math.floor(this.hCanvas / 2) - 4 * this.hSection;

    this.xGridMax = this.xGrid + 8 * this.wSection;
    this.yGridMax = this.yGrid + 8 * this.hSection;

    this.xTopPlayer = this.xGrid;
    this.yTopPlayer = this.yGrid - this.vMarginGrid - this.hSection;

    this.xBottomPlayer = this.xGrid;
    this.yBottomPlayer = this.yGridMax + this.vMarginGrid;

    this.xLeftPlayer = this.xGrid - this.hMarginGrid - this.wSection;
    this.yLeftPlayer = this.yGrid;

    this.xRightPlayer = this.xGridMax + this.hMarginGrid;
    this.yRightPlayer = this.yGrid;

    this.sideOrigin = {
      top: [this.xTopPlayer, this.yTopPlayer],
      bottom: [this.xBottomPlayer, this.yBottomPlayer],
      left: [this.xLeftPlayer, this.yLeftPlayer],
      right: [this.xRightPlayer, this.yRightPlayer],
    };
  },

  drawBlock(ctx, x, y, w, h, ownerNum) {
    const color = PlayerColor[ownerNum].normal;
    const arrow = PlayerArrow[this.playerNum][ownerNum];
    ctx.fillStyle = color;
    ctx.fillRect(x, y, w, h);

    this.drawCenteredText(ctx, x, y, x + w, y + h, arrow);
  },

  drawGrid(ctx, xMin, yMin, wSection, hSection, nRows, nCols) {
    const xMax = xMin + nCols * wSection;
    const yMax = yMin + nRows * hSection;

    for (let row = 0; row < nRows + 1; row += 1) {
      ctx.beginPath();
      ctx.moveTo(xMin, yMin + row * hSection);
      ctx.lineTo(xMax, yMin + row * hSection);
      ctx.strokeStyle = "black";
      ctx.lineWidth = 1;
      ctx.stroke();
    }

    for (let col = 0; col < nCols + 1; col += 1) {
      ctx.beginPath();
      ctx.moveTo(xMin + col * wSection, yMin);
      ctx.lineTo(xMin + col * wSection, yMax);
      ctx.strokeStyle = "black";
      ctx.lineWidth = 1;
      ctx.stroke();
    }
  },

  translateShotSlot(playerNum, slotNum) {
    // Translate a slot number from the perspective of the player to the perspective of the board or
    //   vice versa. This is necessary because the player sees the board rotated 90, 180, or 270 degrees
    //   relative to the board's actual (internal) orientation.

    // For example, Player 1 exists at the top of the internal board.  But the human player sees themselves
    //   at the bottom of the board.  When they click on slot 1 (the leftmost slot),
    //   it corresponds to slot 8 on the internal board (rotate the board 180 degrees).

    // We depend on this.playerNum to know which player we need to translate for, and then we translate
    //   the playerNum and slotNum relative to the player viewing the game (this.playerNum).
    const nSlots = this.nSlots;

    switch (this.playerNum) {
      case 1:
        switch (playerNum) {
          case 1:
            // Current player is player 1, and we want to translate a slot for player 1.
            // Rotate the board 180 degrees, so effectively the slot column is reversed.
            return nSlots - slotNum + 1;
          case 2:
            // Current player is player 1, and we want to translate a slot for player 2.
            // Player 2 is opposite player 1, so after rotating 180 degrees we are still
            //   effectively flipping the slot number.
            return nSlots - slotNum + 1;
          case 3:
            // Same pattern.  Player 3's slot is flipped.
            return nSlots - slotNum + 1;
          case 4:
            // Etc.
            return nSlots - slotNum + 1;
        }
      case 2:
        // Player 2 is naturally the bottom player, so no translations are needed.
        switch (playerNum) {
          case 1:
            return slotNum;
          case 2:
            return slotNum;
          case 3:
            return slotNum;
          case 4:
            return slotNum;
        }
      case 3:
        // Player 3 is naturally on the left side of the board.  Their perspective is rotated 270
        //   degrees (clockwise) from the internal board.
        switch (playerNum) {
          case 1:
            return nSlots - slotNum + 1;
          case 2:
            return nSlots - slotNum + 1;
          case 3:
            return slotNum;
          case 4:
            return slotNum;
        }
      case 4:
        switch (playerNum) {
          case 1:
            return slotNum;
          case 2:
            return slotNum;
          case 3:
            return nSlots - slotNum + 1;
          case 4:
            return nSlots - slotNum + 1;
        }
    }
  },

  translatePosition(r, c, ownerNum) {
    // Similar logic and reasoning as translateShotSlot, but for translating a position on the board.
    const nR = this.nGridRows;
    const nC = this.nGridCols;

    switch (this.playerNum) {
      case 1:
        switch (ownerNum) {
          case 1:
            return [nR - r + 1, nC - c + 1];
          case 2:
            return [nR - r + 1, nC - c + 1];
          case 3:
            return [nR - r + 1, nC - c + 1];
          case 4:
            return [nR - r + 1, nC - c + 1];
        }
      case 2:
        switch (ownerNum) {
          case 1:
            return [r, c];
          case 2:
            return [r, c];
          case 3:
            return [r, c];
          case 4:
            return [r, c];
        }
      case 3:
        switch (ownerNum) {
          case 1:
            return [nC - c + 1, r];
          case 2:
            return [nC - c + 1, r];
          case 3:
            return [nC - c + 1, r];
          case 4:
            return [nC - c + 1, r];
        }
      case 4:
        switch (ownerNum) {
          case 1:
            return [c, nR - r + 1];
          case 2:
            return [c, nR - r + 1];
          case 3:
            return [c, nR - r + 1];
          case 4:
            return [c, nR - r + 1];
        }
    }
  },

  drawActiveBlocks(ctx, activeBlocks, xMin, yMin, wBlock, hBlock) {
    // console.log(activeBlocks);
    activeBlocks.forEach((block) => {
      const pos = parseInt(block.pos);
      const player_num = parseInt(block.player);
      const row = Math.floor(pos / 100);
      const col = pos % 100;

      if (row == 0 || row == this.nGridRows + 1 || col == 0 || col == this.nGridCols + 1) {
        // This block is 1 step outside the board, suggesting it is a new shot that is
        //   staged (holding) and will be placed on the board on the next turn.
        // No need to draw it now.
        return;
      }

      // Translate the internal board position to the player's perspective position.
      const [r, c] = this.translatePosition(row, col, player_num);

      // Calculate the x, y position of the block on the canvas.
      const x = xMin + (c - 1) * wBlock;
      const y = yMin + (r - 1) * hBlock;

      this.drawBlock(ctx, x + 1, y + 1, wBlock - 2, hBlock - 2, player_num);
    });
  },

  drawPlayerSlots(ctx, side) {
    const playerNum = PlayerOnSide[this.playerNum][side];
    for (let i = 1; i <= this.nSlots; i += 1) {
      this.drawShotSlot(side, playerNum, i);
    }

    const [x, y] = this.sideOrigin[side];
    let nRows, nCols;

    if (side === "top" || side === "bottom") {
      nRows = 1;
      nCols = this.nSlots;
    } else {
      nRows = this.nSlots;
      nCols = 1;
    }

    this.drawGrid(ctx, x, y, this.wSection, this.hSection, nRows, nCols);
  },

  drawHoldingShots(ctx, holdingShots) {
    for (const [playerNum, slot] of holdingShots) {
      const side = SideOfOtherPlayer[this.playerNum][playerNum];
      this.drawShotSlot(side, playerNum, slot);
    }
  },

  drawGame() {
    const gameState = this.parseJsonData(this.el.dataset.gameState);
    const ctx = this.context;

    ctx.clearRect(0, 0, this.wCanvas, this.hCanvas);

    this.drawPlayerSlots(ctx, "top", PlayerColor[1]);
    this.drawPlayerSlots(ctx, "bottom", PlayerColor[2]);
    this.drawPlayerSlots(ctx, "left", PlayerColor[3]);
    this.drawPlayerSlots(ctx, "right", PlayerColor[4]);

    this.drawGrid(
      ctx,
      this.xGrid,
      this.yGrid,
      this.wSection,
      this.hSection,
      this.nGridRows,
      this.nGridCols
    );

    this.drawActiveBlocks(
      ctx,
      gameState.active_blocks,
      this.xGrid,
      this.yGrid,
      this.wBlock,
      this.hBlock
    );
  },

  drawCenteredText(ctx, x0, y0, x1, y1, text) {
    // Calculate center of the rectangle
    const centerX = Math.round((x0 + x1) / 2);
    const centerY = Math.round((y0 + y1) / 2);

    ctx.fillStyle = "black"; // Text color
    ctx.font = "16px Arial";
    ctx.textAlign = "center"; // Horizontal alignment
    ctx.textBaseline = "middle"; // Vertical alignment

    ctx.fillText(text, centerX, centerY);
  },
};

export default DrawGame;
