-- Copyright 2021 SmartThings
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--     http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.

local devices = {
  AEOTEC_NANOMOTE_ONE = {
    MATCHING_MATRIX = {
      mfrs = 0x0371,
      product_types = {0x0002, 0x0102},
      product_ids = 0x0004
    },
    CONFIGS = {
      number_of_buttons = 1,
      supported_button_values = {"pushed", "held", "down_hold"}
    }
  },
  FIBARO_BUTTON = {
    MATCHING_MATRIX = {
      mfrs = 0x010F,
      product_types = 0x0F01,
      product_ids = {0x1000, 0x2000, 0x3000}
    },
    CONFIGS = {
      number_of_buttons = 1,
      supported_button_values = {"pushed", "held", "down_hold", "double", "pushed_3x", "pushed_4x", "pushed_5x"}
    }
  },
  AEOTEC_KEYFOB = {
    MATCHING_MATRIX = {
      mfrs = 0x0086,
      product_types = {0x0001, 0x0101},
      product_ids = 0x0058
    },
    CONFIGS = {
      number_of_buttons = 4,
      supported_button_values = {"pushed", "held"}
    }
  },
  AEOTEC_NANOMOTE_QUAD = {
    MATCHING_MATRIX = {
      mfrs = 0x0371,
      product_types = {0x0002, 0x0102},
      product_ids = 0x0003
    },
    CONFIGS = {
      number_of_buttons = 4,
      supported_button_values = {"pushed", "held"}
    }
  },
  AEOTEC_WALLMOTE = {
    MATCHING_MATRIX = {
      mfrs = 0x0086,
      product_types = {0x0002, 0x0102},
      product_ids = 0x0081
    },
    CONFIGS = {
      number_of_buttons = 2,
      supported_button_values = {"pushed", "held"}
    }
  },
  AEOTEC_WALLMOTE_QUAD = {
    MATCHING_MATRIX = {
      mfrs = 0x0086,
      product_types = {0x0002, 0x0102},
      product_ids = 0x0082
    },
    CONFIGS = {
      number_of_buttons = 4,
      supported_button_values = {"pushed", "held"}
    }
  },
  FIBARO_KEYFOB = {
    MATCHING_MATRIX = {
      mfrs = 0x010F,
      product_types = 0x1001,
      product_ids = {0x1000, 0x2000, 0x3000}
    },
    CONFIGS = {
      number_of_buttons = 6,
      supported_button_values = {"pushed", "held", "double", "down_hold", "pushed_3x"}
    }
  },
  EVERSPRING = {
    MATCHING_MATRIX = {
      mfrs = 0x0060,
      product_types = 0x000A,
      product_ids = 0x0003
    },
    CONFIGS = {
      number_of_buttons = 2,
      supported_button_values = {"pushed", "held", "double"}
    }
  },
  AEOTEC_MINIMOTE = {
    MATCHING_MATRIX = {
      mfrs = 0x0086,
      product_types = 0x0001,
      product_ids = 0x0003
    },
    CONFIGS = {
      number_of_buttons = 4,
      supported_button_values = {"pushed", "held"}
    }
  },
  AEOTEC_ILLUMINO = {
    MATCHING_MATRIX = {
      mfrs = 0x0371,
      product_types = 0x0102,
      product_ids = 0x0016
    },
    CONFIGS = {
      number_of_buttons = 2,
      supported_button_values = {"pushed", "held", "down_hold", "double", "pushed_3x", "pushed_4x", "pushed_5x"}
    }
  },
  AEOTEC_PANIC_BUTTON = {
    MATCHING_MATRIX = {
      mfrs = 0x0086,
      product_types = 0x0001,
      product_ids = 0x0026
    },
    CONFIGS = {
      number_of_buttons = 1,
      supported_button_values = {"pushed", "held"}
    }
  },
  RAMOTEC_ZRC_90 = {
    MATCHING_MATRIX = {
      mfrs = 0x5254,
      product_types = {0x0001, 0x0000,0x0002},
      product_ids = 0x8510
    },
    CONFIGS = {
      number_of_buttons = 8,
      supported_button_values = {"pushed", "down_hold", "double", "held"}
    }
  },
  NAMRON_4_KANALER = {
    MATCHING_MATRIX = {
      mfrs = 0x0438,
      product_types = 0x0300,
      product_ids = 0xA305
    },
    CONFIGS = {
      number_of_buttons = 8,
      supported_button_values = {"pushed", "down_hold"}
    },
    NAMRON_2_KANALER = {
      MATCHING_MATRIX = {
        mfrs = {0x0438, 0x0330},
        product_types = 0x0300,
        product_ids = {0xA306, 0xA310}
      },
      CONFIGS = {
        number_of_buttons = 4,
        supported_button_values = {"pushed", "down_hold"}
      }
    }
  },
  NAMRON_1_KANALER = {
    MATCHING_MATRIX = {
      mfrs = {0x0438, 0x0330},
      product_types = 0x0300,
      product_ids = 0xA30F
    },
    CONFIGS = {
      number_of_buttons = 2,
      supported_button_values = {"pushed", "down_hold"}
    }
  },
  GO_CONTROL_WA00Z_1 = {
    MATCHING_MATRIX = {
      mfrs = 0x014F,
      product_types = {0x5343, 0x5754},
      product_ids = {0x3132, 3530}
    },
    CONFIGS = {
      number_of_buttons = 2,
      supported_button_values = {"pushed", "double", "pushed_3x", "down_hold"}
    }
  },
  ENERVAVE_ZWNSC7 = {
    MATCHING_MATRIX = {
      mfrs = 0x011A,
      product_types = 0x0801,
      product_ids = 0x0B03
    },
    CONFIGS = {
      number_of_buttons = 7,
      supported_button_values = {"pushed"}
    }
  },
  NEXIA_NX1000 = {
    MATCHING_MATRIX = {
      mfrs = 0x0178,
      product_types = 0x5343,
      product_ids = 0x4735
    },
    CONFIGS = {
      number_of_buttons = 15,
      supported_button_values = {"pushed", "held", "down_hold"}
    }
  },
  SOMFY_2_BUTTON = {
    MATCHING_MATRIX = {
      mfrs = 0x026E,
      product_types = 0x5643,
      product_ids = 0x5A31
    },
    CONFIGS = {
      number_of_buttons = 2,
      supported_button_values = {"pushed", "held", "down_hold"}
    }
  },
  SOMFY_3_BUTTON = {
    MATCHING_MATRIX = {
      mfrs = 0x026E,
      product_types = 0x4252,
      product_ids = 0x5A31
    },
    CONFIGS = {
      number_of_buttons = 3,
      supported_button_values = {"pushed", "held", "down_hold"}
    }
  },
  SIMON_S100_IO = {
    MATCHING_MATRIX = {
      mfrs = 0x0267,
      product_types = {0x0002, 0x0105},
      product_ids = 0x0000
    },
    CONFIGS = {
      number_of_buttons = 1,
      supported_button_values = {"pushed"}
    }
  },
  VISION_4_BUTTON = {
    MATCHING_MATRIX = {
      mfrs = 0x0109,
      product_types = {0x1002, 0x1004},
      product_ids = {0x0202, 0x0402, 0x0403}
    },
    CONFIGS = {
      number_of_buttons = 4,
      supported_button_values = {"pushed", "held", "down_hold"}
    }
  },
  FUTUREHOME_2_CANAL = {
    MATCHING_MATRIX = {
      mfrs = 0x0305,
      product_types = 0x0300,
      product_ids = 0x0075
    },
    CONFIGS = {
      number_of_buttons = 4,
      supported_button_values = {"pushed", "down_hold"}
    }
  }
}

local DEFAULT_CONFIGS = {
  number_of_buttons = 1,
  supported_button_values = {"pushed", "held"}
}

local configs = {}

configs.get_device_parameters = function(zw_device)
  for _, device in pairs(devices) do
    if zw_device:id_match(
      device.MATCHING_MATRIX.mfrs,
      device.MATCHING_MATRIX.product_types,
      device.MATCHING_MATRIX.product_ids) then
      return device.CONFIGS
    end
  end
  return nil
end

return configs
