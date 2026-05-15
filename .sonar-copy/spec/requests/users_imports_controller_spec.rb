# frozen_string_literal: true

describe 'UsersImportsController' do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account:, role: User::ADMIN_ROLE) }

  before { sign_in admin }

  def csv_upload(content = "email,first_name,last_name,role\none@example.test,One,User,member\n")
    tempfile = Tempfile.new(['users', '.csv'])
    tempfile.write(content)
    tempfile.rewind

    Rack::Test::UploadedFile.new(tempfile.path, 'text/csv', true, original_filename: 'users.csv')
  end

  describe 'GET /users_imports/new' do
    it 'renders upload form' do
      get '/users_imports/new'

      expect(response).to have_http_status(:ok)
    end
  end

  describe 'POST /users_imports' do
    it 'renders unprocessable when file is missing' do
      post '/users_imports'

      expect(response).to have_http_status(:unprocessable_content)
    end

    it 'calls bulk import service and renders create view' do
      file = csv_upload
      result = Users::BulkImport::Result.new
      allow(Users::BulkImport).to receive(:call).and_return(result)

      post '/users_imports', params: { file: file }

      expect(response).to have_http_status(:ok)
      expect(Users::BulkImport).to have_received(:call).with(file: kind_of(ActionDispatch::Http::UploadedFile), account: account)
    end

    it 'renders unprocessable when file format is invalid' do
      file = csv_upload
      allow(Users::BulkImport).to receive(:call).and_raise(Users::BulkImport::InvalidFile, 'invalid')

      post '/users_imports', params: { file: file }

      expect(response).to have_http_status(:unprocessable_content)
    end
  end
end
