class BrowserImage < ApplicationRecord
  validates :name, presence: true
  validates :tag, presence: true, uniqueness: true
end
