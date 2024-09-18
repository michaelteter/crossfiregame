const keyMap = new Map([
  ["a", 1],
  ["1", 1],
  ["s", 2],
  ["2", 2],
  ["d", 3],
  ["3", 3],
  ["f", 4],
  ["4", 4],
  ["j", 5],
  ["5", 5],
  ["k", 6],
  ["6", 6],
  ["l", 7],
  ["7", 7],
  [";", 8],
  ["8", 8],
]);

let GameKeyboardControls = {
  // Handle keyboard events relative to firing shots.
  // We allow keys 1-8 or asdf jkl; to fire shots (which correspond to slots 1-8).

  mounted() {
    this.handleKeyDown = (event) => {
      const key = event.key;

      let slot = keyMap.get(key) || null;

      // switch (key) {
      //   case "a":
      //     slot = 1;
      //     break;
      //   case "s":
      //     slot = 2;
      //     break;
      //   case "d":
      //     slot = 3;
      //     break;
      //   case "f":
      //     slot = 4;
      //     break;
      //   case "j":
      //     slot = 5;
      //     break;
      //   case "k":
      //     slot = 6;
      //     break;
      //   case "l":
      //     slot = 7;
      //     break;
      //   case ";":
      //     slot = 8;
      //     break;
      // }

      // if (!slot) {
      //   const playerSlot = this.keyToPlayerSlot(key);
      //   if (playerSlot) {
      //     slot = playerSlot;
      //   }
      // }

      if (slot) {
        this.pushEvent("shoot", { slot: slot });
      }
    };

    window.addEventListener("keydown", this.handleKeyDown);
  },

  destroyed() {
    window.removeEventListener("keydown", this.handleKeyDown);
  },

  // keyToPlayerSlot(key) {
  //   const numKey = parseInt(key);
  //   if (numKey >= 1 && numKey <= 8) {
  //     return numKey;
  //   }
  //   return null;
  // },
};

export default GameKeyboardControls;
