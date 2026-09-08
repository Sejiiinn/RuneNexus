package auth

import (
	"context"
	"crypto/rand"
	"errors"
	"fmt"
	"math/big"
	"strconv"
	"strings"
	"unicode/utf8"

	"github.com/Sejiiinn/RuneNexus/server/internal/dbgen"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgtype"
)

var (
	ErrInvalidNickname       = errors.New("invalid nickname")
	ErrNicknameAlreadySet    = errors.New("nickname already set")
	ErrNicknameTagsExhausted = errors.New("nickname tags exhausted")
)

type AccountProfile struct {
	AccountID string  `json:"accountId"`
	Nickname  *string `json:"nickname"`
	Tag       *string `json:"tag"`
}

func ValidateNickname(value string) (string, error) {
	value = strings.TrimSpace(value)
	if !utf8.ValidString(value) || utf8.RuneCountInString(value) < 2 {
		return "", ErrInvalidNickname
	}
	width := 0
	for _, character := range value {
		switch {
		case character >= '가' && character <= '힣':
			width += 2
		case character >= 'a' && character <= 'z', character >= 'A' && character <= 'Z', character >= '0' && character <= '9', character == '_':
			width++
		default:
			return "", ErrInvalidNickname
		}
		if width > 16 {
			return "", ErrInvalidNickname
		}
	}
	return value, nil
}

func (service *Service) GetAccountProfile(ctx context.Context, accountID string) (AccountProfile, error) {
	var id pgtype.UUID
	if err := id.Scan(accountID); err != nil {
		return AccountProfile{}, err
	}
	account, err := dbgen.New(service.database).GetAccount(ctx, id)
	if errors.Is(err, pgx.ErrNoRows) {
		return AccountProfile{}, ErrAccessTokenInvalid
	}
	if err != nil {
		return AccountProfile{}, fmt.Errorf("get account profile: %w", err)
	}
	return accountProfile(account)
}

func (service *Service) SetNickname(ctx context.Context, accountID, value string) (AccountProfile, error) {
	nickname, err := ValidateNickname(value)
	if err != nil {
		return AccountProfile{}, err
	}
	var id pgtype.UUID
	if err := id.Scan(accountID); err != nil {
		return AccountProfile{}, err
	}
	tx, err := service.database.BeginTx(ctx, pgx.TxOptions{})
	if err != nil {
		return AccountProfile{}, fmt.Errorf("begin nickname transaction: %w", err)
	}
	defer func() { _ = tx.Rollback(ctx) }()
	queries := dbgen.New(tx)
	// 계정 잠금으로 두 기기의 최초 설정과 재시도 직렬화.
	account, err := queries.GetAccountForUpdate(ctx, id)
	if errors.Is(err, pgx.ErrNoRows) {
		return AccountProfile{}, ErrAccessTokenInvalid
	}
	if err != nil {
		return AccountProfile{}, fmt.Errorf("lock nickname account: %w", err)
	}
	if account.Status != "active" {
		return AccountProfile{}, ErrAccountInactive
	}
	if account.Nickname.Valid {
		if account.Nickname.String != nickname {
			return AccountProfile{}, ErrNicknameAlreadySet
		}
		return accountProfile(account)
	}
	// 같은 이름의 태그 배정을 직렬화하여 충돌과 마지막 한 자리 경쟁 방지.
	if err := queries.LockAccountNickname(ctx, nickname); err != nil {
		return AccountProfile{}, fmt.Errorf("lock nickname: %w", err)
	}
	tags, err := queries.ListAccountNicknameTags(ctx, pgtype.Text{String: nickname, Valid: true})
	if err != nil {
		return AccountProfile{}, fmt.Errorf("list nickname tags: %w", err)
	}
	used := make([]bool, 10000)
	for _, tag := range tags {
		index, parseErr := strconv.Atoi(tag)
		if parseErr != nil || index < 0 || index >= len(used) {
			return AccountProfile{}, errors.New("invalid stored nickname tag")
		}
		used[index] = true
	}
	available := make([]int, 0, len(used)-len(tags))
	for tag, taken := range used {
		if !taken {
			available = append(available, tag)
		}
	}
	if len(available) == 0 {
		return AccountProfile{}, ErrNicknameTagsExhausted
	}
	choice, err := rand.Int(rand.Reader, big.NewInt(int64(len(available))))
	if err != nil {
		return AccountProfile{}, fmt.Errorf("generate nickname tag: %w", err)
	}
	tag := fmt.Sprintf("%04d", available[choice.Int64()])
	account, err = queries.SetAccountNickname(ctx, dbgen.SetAccountNicknameParams{ID: id, Nickname: pgtype.Text{String: nickname, Valid: true}, NicknameTag: pgtype.Text{String: tag, Valid: true}})
	if err != nil {
		return AccountProfile{}, fmt.Errorf("set nickname: %w", err)
	}
	if err := tx.Commit(ctx); err != nil {
		return AccountProfile{}, fmt.Errorf("commit nickname: %w", err)
	}
	return accountProfile(account)
}

func accountProfile(account dbgen.Account) (AccountProfile, error) {
	if account.Status != "active" {
		return AccountProfile{}, ErrAccountInactive
	}
	id, err := formatUUID(account.ID)
	if err != nil {
		return AccountProfile{}, err
	}
	result := AccountProfile{AccountID: id}
	if account.Nickname.Valid && account.NicknameTag.Valid {
		result.Nickname = &account.Nickname.String
		result.Tag = &account.NicknameTag.String
	}
	return result, nil
}
