variable "subscription" {
  type        = string
  description = "description"
  validation {
    condition     = contains(["NP", "P"], var.subscription)
    error_message = "The subscription must be one of [NP, P]"
  }
}
