-- Overwrite vanilla recipes
data:extend({
{
  type = "recipe",
  name = "label_lamp",
  enabled = true,
  ingredients =
  {
    {"electronic-circuit", 2},
    {"iron-stick", 3},
    {"iron-plate", 1}
  },
  result = "label_lamp"
},
})