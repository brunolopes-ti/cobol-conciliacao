INSERT INTO cobrancas (identificador, valor_esperado) VALUES
('COB001', 100.50),
('COB002', 200.00),
('COB003', 75.25),
('COB004', 90.00);

INSERT INTO pagamentos (identificador_cobranca, valor_pago) VALUES
('COB001', 100.50),
('COB002', 180.00),
('COB999', 50.00),
('COB001', 100.50),
('COB003', 75.25);
