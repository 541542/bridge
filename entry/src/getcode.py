import os
import glob

def merge_java_files():
    # 获取当前目录及所有子目录下的.java文件
    java_files = glob.glob('**/*.ts', recursive=True)

    if not java_files:
        print("未找到任何.java文件")
        return

    # 创建输出文件
    output_file = 'merged_ts_files.txt'

    with open(output_file, 'w', encoding='utf-8') as outfile:
        for java_file in java_files:
            print(f"正在处理: {java_file}")

            # 写入文件分隔符和文件名
            outfile.write(f"\n{'='*60}\n")
            outfile.write(f"文件: {java_file}\n")
            outfile.write(f"{'='*60}\n\n")

            try:
                # 读取Java文件内容
                with open(java_file, 'r', encoding='utf-8') as infile:
                    content = infile.read()
                    outfile.write(content)
                    outfile.write('\n\n')
            except Exception as e:
                outfile.write(f"读取文件时出错: {str(e)}\n\n")
                print(f"读取 {java_file} 时出错: {str(e)}")

    print(f"合并完成！共处理了 {len(java_files)} 个xml文件")
    print(f"输出文件: {output_file}")

    # 显示处理的文件列表
    print("\n处理的文件列表:")
    for java_file in java_files:
        print(f"  - {java_file}")

if __name__ == "__main__":
    merge_java_files()
