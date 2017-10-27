require "spec_helper"

describe Gitlab::Git::Branch, seed_helper: true do
  let(:repository) { Gitlab::Git::Repository.new('default', TEST_REPO_PATH, '') }

  subject { repository.branches }

  it { is_expected.to be_kind_of Array }

  describe '.find' do
    subject { described_class.find(repository, branch) }

    before do
      allow(repository).to receive(:find_branch).with(branch)
        .and_call_original
    end

    context 'when finding branch via branch name' do
      let(:branch) { 'master' }

      it 'returns a branch object' do
        expect(subject).to be_a(described_class)
        expect(subject.name).to eq(branch)

        expect(repository).to have_received(:find_branch).with(branch)
      end
    end

    context 'when the branch is already a branch' do
      let(:commit) { repository.commit('master') }
      let(:branch) { described_class.new(repository, 'master', commit.sha, commit) }

      it 'returns a branch object' do
        expect(subject).to be_a(described_class)
        expect(subject).to eq(branch)

        expect(repository).not_to have_received(:find_branch).with(branch)
      end
    end
  end

  describe '#size' do
    subject { super().size }
    it { is_expected.to eq(SeedRepo::Repo::BRANCHES.size) }
  end

  describe 'first branch' do
    let(:branch) { repository.branches.first }

    it { expect(branch.name).to eq(SeedRepo::Repo::BRANCHES.first) }
    it { expect(branch.dereferenced_target.sha).to eq("0b4bc9a49b562e85de7cc9e834518ea6828729b9") }
  end

  describe 'master branch' do
    let(:branch) do
      repository.branches.find { |branch| branch.name == 'master' }
    end

    it { expect(branch.dereferenced_target.sha).to eq(SeedRepo::LastCommit::ID) }
  end

  it { expect(repository.branches.size).to eq(SeedRepo::Repo::BRANCHES.size) }
end
