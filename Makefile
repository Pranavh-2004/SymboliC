CC      := cc
CFLAGS  := -Wall -Wextra -std=c11 -g

SRC_DIR := src
BIN_DIR := bin
TARGET  := $(BIN_DIR)/pe3_symbol_table

all: $(TARGET)

$(BIN_DIR):
	mkdir -p $(BIN_DIR)

$(SRC_DIR)/parser.tab.c $(SRC_DIR)/parser.tab.h: $(SRC_DIR)/parser.y
	bison -d -o $(SRC_DIR)/parser.tab.c $(SRC_DIR)/parser.y

$(SRC_DIR)/lex.yy.c: $(SRC_DIR)/lexer.l $(SRC_DIR)/parser.tab.h
	flex -o $(SRC_DIR)/lex.yy.c $(SRC_DIR)/lexer.l

$(TARGET): $(BIN_DIR) $(SRC_DIR)/parser.tab.c $(SRC_DIR)/lex.yy.c \
          $(SRC_DIR)/symbol_table.c $(SRC_DIR)/main.c
	$(CC) $(CFLAGS) -o $(TARGET) \
		$(SRC_DIR)/parser.tab.c \
		$(SRC_DIR)/lex.yy.c \
		$(SRC_DIR)/symbol_table.c \
		$(SRC_DIR)/main.c

run: $(TARGET)
	$(TARGET) input/sample.c

clean:
	rm -rf $(BIN_DIR) $(SRC_DIR)/parser.tab.c $(SRC_DIR)/parser.tab.h $(SRC_DIR)/lex.yy.c

.PHONY: all clean run
