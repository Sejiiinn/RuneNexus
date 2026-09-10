package main

import (
	"context"
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"io"
	"os"
	"time"

	"github.com/Sejiiinn/RuneNexus/server/internal/economy"
	"github.com/jackc/pgx/v5/pgxpool"
)

func main() {
	if err := run(); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}
func run() error {
	action := flag.String("action", "validate", "validate, create, disable")
	file := flag.String("file", "", "우편 JSON 파일 (dispatchKey UUID, title, body, freeDiamonds, moduleTickets, audience, targetAccountIds, startsAt, expiresAt, createdBy, 선택 eligibilityCutoff)")
	id := flag.String("id", "", "중지할 우편 ID")
	operator := flag.String("operator", "", "중지 작업자")
	flag.Parse()
	if *action != "validate" && *action != "create" && *action != "disable" {
		return errors.New("action must be validate, create or disable")
	}
	var input economy.CreateMailRequest
	if *action != "disable" {
		source, err := os.Open(*file)
		if err != nil {
			return err
		}
		defer source.Close()
		decoder := json.NewDecoder(io.LimitReader(source, 4<<20))
		decoder.DisallowUnknownFields()
		if err := decoder.Decode(&input); err != nil {
			return err
		}
		if err := decoder.Decode(&struct{}{}); err != io.EOF {
			return errors.New("one JSON object required")
		}
		if err := economy.ValidateMail(&input); err != nil {
			return err
		}
		if *action == "validate" {
			return json.NewEncoder(os.Stdout).Encode(input)
		}
	}
	databaseURL := os.Getenv("DATABASE_URL")
	if databaseURL == "" {
		return errors.New("DATABASE_URL is required")
	}
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	pool, err := pgxpool.New(ctx, databaseURL)
	if err != nil {
		return err
	}
	defer pool.Close()
	service := economy.NewService(pool)
	if *action == "disable" {
		if err := service.DisableMail(ctx, *id, *operator); err != nil {
			return err
		}
		fmt.Println("우편 중지:", *id)
		return nil
	}
	mailID, err := service.CreateMail(ctx, input)
	if err != nil {
		return err
	}
	fmt.Println("우편 등록:", mailID)
	return nil
}
