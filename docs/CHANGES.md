v2.0.5-------------------------------------------------------------------
- Added - Icon to the CCU prefix for improved visibility - [core.lua]
- Added - `/ccu help` command to display a list of available commands and descriptions - [core.lua]
- Fixed - Adjusted button visibility and secure button creation for better reliability - [core.lua]
- Fixed - Corrected slash command registration for `/ccu` and updated the login message to reflect the correct command - [core.lua]
- Fixed - Improved re-equipping logic to ensure the original cloak is only cleared after successful re-equip - [core.lua]
- Fixed - Resolved an issue where the welcome message toggle was not saving its state properly across sessions - [core.lua]
- Updated - Combined `cloakIDs` and `cloakNames` into a single `cloaks` table for improved maintainability - [core.lua]
- Updated - Refactored functions to use the new combined `cloaks` table structure - [core.lua]
