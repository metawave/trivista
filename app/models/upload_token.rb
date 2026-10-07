class UploadToken < ApplicationRecord
  belongs_to :service_account
  belongs_to :created_by, class_name: "User"
end
