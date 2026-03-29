/*
 * @Author: [[ .AuthorName ]] [[ .AuthorEmail ]]
 * @Date: [[ nowFmt "2006-01-02" ]] 00:00:00
 * @LastEditors: [[ .AuthorName ]] [[ .AuthorEmail ]]
 * @LastEditTime: [[ nowFmt "2006-01-02" ]] 00:00:00
 * @FilePath: \[[ .ProjectName ]]\bootstrap\generate_handler.go
 * @Description: [[ .ProjectName ]] API 代码生成接口处理器
 *
 * Copyright (c) [[ .Year ]] by [[ .AuthorName ]], All Rights Reserved.
 */
package main

import (
	"archive/zip"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"time"

	gwglobal "github.com/kamalyes/go-rpc-gateway/global"
)

var (
	swaggerOutputFile = "[[ .OrgPrefix ]]-openapi-service.swagger.json"
	zipOutputFile     = "generate.zip"
)

func GenerateHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	workDir := filepath.Join(os.TempDir(), fmt.Sprintf("openapi-gen-%d", time.Now().Unix()))
	if err := os.MkdirAll(workDir, 0755); err != nil {
		http.Error(w, fmt.Sprintf("创建工作目录失败: %v", err), http.StatusInternalServerError)
		return
	}
	defer os.RemoveAll(workDir)

	swaggerURL := fmt.Sprintf("http://%s:%d/swagger/aggregate.json", gwglobal.GetConfig().HTTPServer.Host, gwglobal.GetConfig().HTTPServer.Port)
	swaggerFilePath := filepath.Join(workDir, swaggerOutputFile)
	if err := downloadSwagger(swaggerURL, swaggerFilePath); err != nil {
		http.Error(w, fmt.Sprintf("下载Swagger文件失败: %v", err), http.StatusInternalServerError)
		return
	}

	generatePath := filepath.Join(workDir, "generate")
	if err := runOpenAPIGenerator(swaggerFilePath, generatePath); err != nil {
		http.Error(w, fmt.Sprintf("生成代码失败: %v", err), http.StatusInternalServerError)
		return
	}

	zipFilePath := filepath.Join(workDir, zipOutputFile)
	if err := zipDirectory(generatePath, zipFilePath); err != nil {
		http.Error(w, fmt.Sprintf("压缩文件失败: %v", err), http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/zip")
	w.Header().Set("Content-Disposition", fmt.Sprintf("attachment; filename=%s", zipOutputFile))

	zipFile, err := os.Open(zipFilePath)
	if err != nil {
		http.Error(w, fmt.Sprintf("打开压缩文件失败: %v", err), http.StatusInternalServerError)
		return
	}
	defer zipFile.Close()

	if _, err := io.Copy(w, zipFile); err != nil {
		fmt.Printf("发送文件失败: %v\n", err)
	}
}

func downloadSwagger(url, outputPath string) error {
	resp, err := http.Get(url)
	if err != nil {
		return fmt.Errorf("请求Swagger URL失败: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("获取Swagger文件失败,状态码: %d", resp.StatusCode)
	}

	var jsonData interface{}
	bodyBytes, err := io.ReadAll(resp.Body)
	if err != nil {
		return fmt.Errorf("读取响应失败: %w", err)
	}

	if err := json.Unmarshal(bodyBytes, &jsonData); err != nil {
		return fmt.Errorf("Swagger内容不是有效的JSON: %w", err)
	}

	if err := os.WriteFile(outputPath, bodyBytes, 0644); err != nil {
		return fmt.Errorf("保存Swagger文件失败: %w", err)
	}

	return nil
}

func runOpenAPIGenerator(inputFile, outputDir string) error {
	args := []string{
		"openapi-generator-cli",
		"generate",
		"-i", inputFile,
		"-g", "typescript-axios",
		"-o", outputDir,
		"--additional properties",
		"modelPropertyNaming=original,stringEnums=true,withSeparateModelsAndApi=true,modelPackage=models,apiPackage=apis,supportsES6=true,enumPropertyNaming=UPPERCASE",
	}

	cmd := exec.Command(args[0], args[1:]...)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr

	if err := cmd.Run(); err != nil {
		return fmt.Errorf("执行openapi-generator-cli失败: %w", err)
	}

	return nil
}

func zipDirectory(sourceDir, zipFilePath string) error {
	zipFile, err := os.Create(zipFilePath)
	if err != nil {
		return fmt.Errorf("创建zip文件失败: %w", err)
	}
	defer zipFile.Close()

	archive := zip.NewWriter(zipFile)
	defer archive.Close()

	err = filepath.Walk(sourceDir, func(path string, info os.FileInfo, err error) error {
		if err != nil {
			return err
		}

		header, err := zip.FileInfoHeader(info)
		if err != nil {
			return err
		}

		relPath, err := filepath.Rel(sourceDir, path)
		if err != nil {
			return err
		}
		header.Name = filepath.ToSlash(relPath)

		if info.IsDir() {
			header.Name += "/"
		} else {
			header.Method = zip.Deflate
		}

		writer, err := archive.CreateHeader(header)
		if err != nil {
			return err
		}

		if !info.IsDir() {
			file, err := os.Open(path)
			if err != nil {
				return err
			}
			defer file.Close()
			_, err = io.Copy(writer, file)
			return err
		}

		return nil
	})

	return err
}
