local inputs = {
	_menuPress_delay = 20,
	_menuPress_period = 3,
	_pressThreshold = 80,    -- Threshold at which sticks will count as button presses
	_releaseThreshold = 48,  -- Threshold below which sticks will release a held button
	_analogOvershootCooldown = 3, -- When releasing an analog stick quickly, it can overshoot and register an input in the other direction. This is used to prevent that.
}

-- Define the inputs we want to track.
-- "raw" inputs pull data directly from the controller.
-- "abstract" inputs are calculated based on other inputs,
-- such as to break analog inputs into seperate left and
-- right inputs or create an input that reacts to multiple
-- other inputs.
inputs._inputTypes = {
	{_name = "X", _type = "raw", _form = "button", _target = "Cross"},
	{_name = "circle", _type = "raw", _form = "button", _target = "Circle"},
	{_name = "square", _type = "raw", _form = "button", _target = "Square"},
	{_name = "triangle", _type = "raw", _form = "button", _target = "Triangle"},
	
	{_name = "dPad_left", _type = "raw", _form = "button", _target = "Left"},
	{_name = "dPad_right", _type = "raw", _form = "button", _target = "Right"},
	{_name = "dPad_up", _type = "raw", _form = "button", _target = "Up"},
	{_name = "dPad_down", _type = "raw", _form = "button", _target = "Down"},
	
	{_name = "R1", _type = "raw", _form = "button", _target = "R1"},
	{_name = "R2", _type = "raw", _form = "button", _target = "R2"},
	{_name = "R3", _type = "raw", _form = "button", _target = "R3"},
	
	{_name = "L1", _type = "raw", _form = "button", _target = "L1"},
	{_name = "L2", _type = "raw", _form = "button", _target = "L2"},
	{_name = "L3", _type = "raw", _form = "button", _target = "L3"},
	
	{_name = "start", _type = "raw", _form = "button", _target = "Start"},
	{_name = "select", _type = "raw", _form = "button", _target = "Select"},
	{_name = "mode", _type = "raw", _form = "button", _target = "Mode"},
	
	{_name = "leftStick_x", _type = "raw", _form = "analog", _target = "LStick X"},
	{_name = "leftStick_right", _type = "abstract", _form = "button", _calculation = {_type = "analog+", _target = "leftStick_x"}},
	{_name = "leftStick_left", _type = "abstract", _form = "button", _calculation = {_type = "analog-", _target = "leftStick_x"}},
	{_name = "leftStick_y", _type = "raw", _form = "analog", _target = "LStick Y"},
	{_name = "leftStick_up", _type = "abstract", _form = "button", _calculation = {_type = "analog-", _target = "leftStick_y"}},
	{_name = "leftStick_down", _type = "abstract", _form = "button", _calculation = {_type = "analog+", _target = "leftStick_y"}},
	
	{_name = "rightStick_x", _type = "raw", _form = "analog", _target = "RStick X"},
	{_name = "rightStick_right", _type = "abstract", _form = "button", _calculation = {_type = "analog+", _target = "rightStick_x"}},
	{_name = "rightStick_left", _type = "abstract", _form = "button", _calculation = {_type = "analog-", _target = "rightStick_x"}},
	{_name = "rightStick_y", _type = "raw", _form = "analog", _target = "RStick Y"},
	{_name = "rightStick_up", _type = "abstract", _form = "button", _calculation = {_type = "analog-", _target = "rightStick_y"}},
	{_name = "rightStick_down", _type = "abstract", _form = "button", _calculation = {_type = "analog+", _target = "rightStick_y"}},
	
	{_name = "any_left", _type = "abstract", _form = "button",
		_calculation = {
			_type = "or",
			_operands = {
				{_type = "button", _target = "dPad_left"},
				{_type = "button", _target = "leftStick_left"},
				{_type = "button", _target = "rightStick_left"},
			},
		},
	},
	{_name = "any_right", _type = "abstract", _form = "button",
		_calculation = {
			_type = "or",
			_operands = {
				{_type = "button", _target = "dPad_right"},
				{_type = "button", _target = "leftStick_right"},
				{_type = "button", _target = "rightStick_right"},
			},
		},
	},
	{_name = "any_up", _type = "abstract", _form = "button",
		_calculation = {
			_type = "or",
			_operands = {
				{_type = "button", _target = "dPad_up"},
				{_type = "button", _target = "leftStick_up"},
				{_type = "button", _target = "rightStick_up"},
			},
		},
	},
	{_name = "any_down", _type = "abstract", _form = "button",
		_calculation = {
			_type = "or",
			_operands = {
				{_type = "button", _target = "dPad_down"},
				{_type = "button", _target = "leftStick_down"},
				{_type = "button", _target = "rightStick_down"},
			},
		},
	},
}

--This is the processing that is done on inputTypes on when
--this module is loaded to set up the initial data for the
--inputs.
for i, v in ipairs(inputs._inputTypes) do	
	if v._form == "button" then
		inputs[v._name] = {
			value = false,
			press = false,
			menuPress = false,
			release = false,
			pressTime = 0,
		}
	elseif v._form == "analog" then
		inputs[v._name] = {
			value = 128,
			positiveButton = false,
			negativeButton = false,
			overshootCooldown = 0,
		}
	end
end

--Call this once at the start of the frame to update everything.
function inputs:update()
	local joy = joypad.get(1)
	
	-- This subfunction updates updates the value, press,
	-- release, etc. of a single input, given a new value.
	local function _updateInput(thisInput, definition, newValue)
		if definition._form == "button" then
			local oldValue = thisInput.value
			thisInput.value = newValue
			
			thisInput.press = newValue and not oldValue
			thisInput.release = not newValue and oldValue
			
			if newValue then
				thisInput.pressTime = thisInput.pressTime + 1
				thisInput.menuPress = thisInput.pressTime == 1 or (thisInput.pressTime >= self._menuPress_delay and (thisInput.pressTime - self._menuPress_delay) % self._menuPress_period == 0)
			else
				thisInput.pressTime = 0
				thisInput.menuPress = false
			end
		elseif definition._form == "analog" then
			thisInput.overshootCooldown = thisInput.overshootCooldown - 1
			if thisInput.overshootCooldown < 0 then thisInput.overshootCooldown = 0 end
			
			if (thisInput.positiveButton and newValue <= 128 + self._releaseThreshold) or (thisInput.negativeButton and newValue >= 128 - self._releaseThreshold) then thisInput.overshootCooldown = self._analogOvershootCooldown end
			
			thisInput.value = newValue
			thisInput.positiveButton = thisInput.positiveButton and (newValue > 128 + self._releaseThreshold) or (newValue > 128 + self._pressThreshold and thisInput.overshootCooldown == 0)
			thisInput.negativeButton = thisInput.negativeButton and (newValue < 128 - self._releaseThreshold) or (newValue < 128 - self._pressThreshold and thisInput.overshootCooldown == 0)
		end		
	end
	
	local function _calculateAbstract(data)
		if data._type == "analog+" then
			return self[data._target].positiveButton
		elseif data._type == "analog-" then
			return self[data._target].negativeButton
		elseif data._type == "button" then
			return self[data._target].value
		elseif data._type == "or" then
			for i, v in ipairs(data._operands) do
				if _calculateAbstract(v) then return true end
			end
			return false
		elseif data._type == "and" then
			for i, v in ipairs(data._operands) do
				if not _calculateAbstract(v) then return false end
			end
			return true
		elseif data._type == "xor" then
			local n = 0
			for i, v in ipairs(data._operands) do
				if _calculateAbstract(v) then n = n + 1 end
			end
			return n % 2 == 1
		elseif data._type == "not" then
			return not _calculateAbstract(data._operand)
		end
		return false
	end
	
	for i, v in ipairs(self._inputTypes) do
		if v._type == "raw" then
			_updateInput(self[v._name], v, joy[v._target])
		elseif v._type == "abstract" then
			_updateInput(self[v._name], v, _calculateAbstract(v._calculation))
		end
	end
end

return inputs